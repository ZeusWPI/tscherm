module app.main;

import app.fullscreen_log : FullscreenLog;
import app.pong.pong : Pong;
import app.singleton : Singleton;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.font : Font;
import app.vga.framebuffer_interrupt.interrupt : FrameBufferInterrupt;
import app.vga.framebuffer_interrupt.interrupt_drawer : InterruptDrawer;
import app.vga.video_timings;

import idf.esp_common.esp_err : ESP_ERROR_CHECK;
import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : pdPASS, TaskHandle_t, ulTaskGenericNotifyTake, vTaskDelay, vTaskSuspend, xTaskCreatePinnedToCore;

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

    // Provides `createInstance` and `instance`
    mixin Singleton;

    struct Config
    {
        enum VideoTimings vt = VIDEO_TIMINGS_640W_480H_MAC;

        enum size_t lineBufferCount = 16;
        enum size_t drawBatchSize = 8;

        enum uint i2sIndex = 1;
        enum uint bitCount = 8;

        enum int[] colorPins = [14, 27, 16, 17, 25, 26];
        enum int cSyncPin = 12;

        alias font = Font!();

        // enum string wifiSsid = "Zeus WPI";
        // enum string wifiPassword = "zeusisdemax";

        // enum ushort pongTcpServerPort = 777;

        static assert(lineBufferCount % drawBatchSize == 0);
        static assert(drawBatchSize <= lineBufferCount / 2);
    }

    private TaskHandle_t m_loopTask;

    private FrameBufferInterrupt!(Config.vt, Config.lineBufferCount) m_fb;
    private I2SSignalGenerator!(Config.i2sIndex, Config.bitCount, Config.vt.pixelClock, true) m_i2sSignalGenerator;
    private DMADescriptorRing m_dmaDescriptorRing;

    // private InterruptDrawer!(Config.vt) m_interruptDrawer;
    private FullscreenLog!(Config.vt.h.res, Config.vt.v.res, Config.font) m_fullscreenLog;
    // private bool m_fullscreenLogActive;
    // private WifiClient m_wifiClient;
    // private Pong m_pong;

    private
    void initialize()
    {
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
            assert(result == pdPASS);
            // dfmt on
        })();

        logAll!("Initializing FrameBuffer");
        m_fb.initialize;

        logAll!"Initializing DMADescriptorRing";
        m_dmaDescriptorRing = DMADescriptorRing(m_fb.allBuffers.length);
        m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.allBuffers)());

        logAll!"Initializing I2SSignalGenerator";
        m_i2sSignalGenerator.initialize(m_loopTask);

        logAll!"Setting descriptor eof flags";
        // dfmt off
        for (
            size_t i = Config.vt.v.resStart + Config.drawBatchSize * 2 - 1;
            i < m_dmaDescriptorRing.descriptors.length;
            i += Config.drawBatchSize * 2
        )
            m_dmaDescriptorRing.descriptors[i].eof = 1;
        // dfmt on

        // dfmt off
        logAll!"Routing GPIO signals";
        UniqueHeapArray!Signal signals = m_i2sSignalGenerator.getSignals;
        static foreach(i, int pin; Config.colorPins)
            route(from: signals.get[i], to: GPIOPin(pin), invert: false);
        route(from: signals.get[$ - 1], to: GPIOPin(Config.cSyncPin), invert: true);
        // dfmt on

        logAll!"Starting VGA output";
        m_i2sSignalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

        // logAll!"Initializing InterruptDrawer";
        // m_interruptDrawer.initialize;

        logAll!"Initializing FullscreenLog";
        m_fullscreenLog.initialize;
        // m_fullscreenLogActive = true;

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

        while (true)
        {
            // dfmt off
            const size_t currDescAddr = ulTaskGenericNotifyTake(
                uxIndexToWaitOn: 0,
                xClearCountOnExit: true,
                xTicksToWait: 10_000,
            );
            // dfmt on

            const size_t firstDescAddr = cast(size_t) m_dmaDescriptorRing.firstDescriptor;
            const size_t descCount = m_dmaDescriptorRing.descriptors.length;

            assert(currDescAddr >= firstDescAddr);
            assert((currDescAddr - firstDescAddr) % lldesc_t.sizeof == 0);
            const size_t currDescIndex = (currDescAddr - firstDescAddr) / lldesc_t.sizeof;
            const size_t nextDescIndex = (currDescIndex + 1) % descCount;

            const uint currY = () {
                if (Config.vt.v.resStart <= nextDescIndex)
                    return (nextDescIndex - Config.vt.v.resStart) / 2;
                else
                    return 0;
            }();

            assert(currY < Config.vt.v.res);

            foreach (drawY; currY + Config.lineBufferCount / 2 .. currY + 16)
            {
                drawY %= Config.vt.v.res;
                m_fullscreenLog.drawLine(m_fb.getLine(drawY), drawY);
            }
        }
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
