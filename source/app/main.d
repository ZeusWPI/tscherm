module app.main;

import app.fullscreen_log : FullscreenLog;
import app.pong.pong : Pong;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.framebuffer;
import app.vga.framebuffer_interrupt.interrupt;
import app.vga.framebuffer_interrupt.interrupt_drawer;
import app.vga.video_timings;

import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : pdPASS, TaskHandle_t, ulTaskGenericNotifyTake,
    vTaskDelay, xTaskGenericNotifyFromISR, vTaskSuspend,
    xTaskCreatePinnedToCore, eNotifyAction;

import idf.esp_timer : esp_timer_get_time;
import idfd.log : Logger;
import idfd.net.wifi_client : WifiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;

import ldc.attributes : section;

import ministd.typecons : UniqueHeap, UniqueHeapArray;

import core.volatile : volatileLoad;
import idf.soc.i2s_reg : REG_I2S_BASE;

@safe:

struct TScherm
{
    enum log = Logger!"TScherm"();

    // Begin of singleton pattern
    private __gshared bool s_instanceInitialized;
    private __gshared TScherm s_instance;

    static @trusted
    void createInstance()
    in (!s_instanceInitialized)
    {
        s_instanceInitialized = true;
        s_instance.initialize;
    }

    static @trusted nothrow @nogc pragma(inline, true)
    ref TScherm instance()
    in (s_instanceInitialized)
        => s_instance;
    // End of singleton pattern

    struct Config
    {
        static immutable(VideoTimings)* vt = &VIDEO_TIMINGS_640W_480H_MAC;

        enum size_t batchSize = 8;

        enum int whitePin = 25;
        enum int cSyncPin = 26;

        enum string wifiSsid = "Zeus WPI";
        enum string wifiPassword = "zeusisdemax";

        enum ushort pongTcpServerPort = 777;
    }

    private FrameBufferInterrupt!16 m_fb;
    private FullscreenLog m_fullscreenLog;
    private bool m_fullscreenLogActive;
    private I2SSignalGenerator m_signalGenerator;
    private DMADescriptorRing m_dmaDescriptorRing;
    private WifiClient m_wifiClient;
    private Pong m_pong;
    private InterruptDrawer m_interruptDrawer;
    private TaskHandle_t m_loopTask;

    private
    void initialize()
    {
        logAll!("Initializing " ~ typeof(m_fb).stringof);
        m_fb.initialize(Config.vt);

        logAll!"Initializing FullscreenLog";
        // m_fullscreenLog = FullscreenLog(m_fb);
        // m_fullscreenLogActive = true;

        logAll!"Initializing I2SSignalGenerator";
        // dfmt off
        m_signalGenerator = I2SSignalGenerator(
            i2sIndex: 1,
            bitCount: 8,
            freq: Config.vt.pixelClock,
        );
        // dfmt on

        logAll!"Initializing DMADescriptorRing";
        m_dmaDescriptorRing = DMADescriptorRing(m_fb.allBuffers.length);
        m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.allBuffers)());

        logAll!"Setting descriptor eof flags";
        foreach (i, ref lldesc_t desc; m_dmaDescriptorRing.descriptors)
            if (Config.vt.v.resStart <= i)
            {
                uint resBufferIndex = i - Config.vt.v.resStart;
                if (resBufferIndex % 2 == 1)
                {
                    uint y = resBufferIndex / 2;
                    if (y % 8 == 7)
                        desc.eof = 1;
                }
            }

        // dfmt off
        logAll!"Routing GPIO signals";
        UniqueHeapArray!Signal signals = m_signalGenerator.getSignals;
        route(from: signals.get[0], to: GPIOPin(14), invert: false); // White
        route(from: signals.get[1], to: GPIOPin(27), invert: false); // White
        route(from: signals.get[2], to: GPIOPin(16), invert: false); // White
        route(from: signals.get[3], to: GPIOPin(17), invert: false); // White
        route(from: signals.get[4], to: GPIOPin(25), invert: false); // White
        route(from: signals.get[5], to: GPIOPin(26), invert: false); // White
        route(from: signals.get[7], to: GPIOPin(12), invert: true ); // CSync
        // dfmt on

        logAll!"Creating loop task";
        (() @trusted {
            // dfmt off
            auto result = xTaskCreatePinnedToCore(
                pvTaskCode: &TScherm.loopTaskEntrypoint,
                pcName: "loop",
                usStackDepth: 4000,
                pvParameters: null,
                uxPriority: 10,
                pvCreatedTask: &m_loopTask,
                xCoreID: 1,
            );
            // dfmt on
            if (result != pdPASS)
                assert(false);
        })();

        logAll!"Starting VGA output";
        m_signalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

        // logAll!"Initializing WifiClient (async)";
        // m_wifiClient = WifiClient(Config.wifiSsid, Config.wifiPassword);
        // m_wifiClient.startAsync;

        // logAll!("Connecting to AP with ssid: " ~ Config.wifiSsid);
        // m_wifiClient.waitForConnection;

        // fullscreenLog.clear;
        // logAll!("Connected to " ~ Config.wifiSsid ~ "!");
        // (() @trusted => vTaskDelay(100))();

        // logAll!"Starting Pong";
        // (() @trusted => vTaskDelay(100))();
        // m_fullscreenLogActive = false;
        // m_pong = Pong(m_fb);

        logAll!"Initializing InterruptDrawer";
        m_interruptDrawer.initialize;
    }

    private
    void logAll(string fmt, Args...)(Args args)
    {
        log.info!fmt(args);
        // if (m_fullscreenLogActive)
        //     m_fullscreenLog.writeln(fmt);
    }

    private static @trusted extern (C)
    void loopTaskEntrypoint(void* ignore)
        => TScherm.instance.loop;

    private @trusted
    void loop()
    {
        // The first log from this task seems to take 0.5ms extra, so get it out of the way
        log.info!"Loop task running";

        long lines;
        long totalIdleTime;
        long totalDrawTime;

        while (true)
        {
            long idleStartTime = esp_timer_get_time;
            // dfmt off
            uint currY = ulTaskGenericNotifyTake(
                uxIndexToWaitOn: 0,
                xClearCountOnExit: true,
                xTicksToWait: 10_000,
            );
            // dfmt on
            if (currY != 8)
                totalIdleTime += esp_timer_get_time - idleStartTime;

            long drawStartTime = esp_timer_get_time;
            foreach (drawY; currY + 8 .. currY + 16)
            {
                drawY %= Config.vt.v.res;
                m_interruptDrawer.drawLine(
                    m_fb.getLine(drawY),
                    drawY,
                    0,
                );
            }
            if (currY != 8)
                totalDrawTime += esp_timer_get_time - drawStartTime;

            if (currY != 8)
                lines += 8;

            if (lines % 10_000 == 0)
            {
                log.info!"line %lld: avgIdle=%llf avgDraw=%llf"(
                    lines,
                    1.0 * totalIdleTime / lines,
                    1.0 * totalDrawTime / lines,
                );
            }
        }
    }

    @section(".iram1")
    static @trusted nothrow @nogc extern (C)
    void onBufferCompleted()
    {
        __gshared uint currY;

        currY += 8;
        if (currY >= 480)
            currY = 0;

        // dfmt off
        xTaskGenericNotifyFromISR(
            xTaskToNotify: TScherm.s_instance.m_loopTask,
            uxIndexToNotify: 0,
            ulValue: currY,
            eAction: eNotifyAction.eSetValueWithOverwrite,
            pulPreviousNotificationValue: null,
            pxHigherPriorityTaskWoken: null,
        );
        // dfmt on
    }
}

extern (C)
void app_main()
{
    TScherm.createInstance;

    while (true)
    {
        vTaskSuspend(null);
    }
}
