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

        enum uint i2sIndex = 1;
        enum uint bitCount = 8;

        enum int[] colorPins = [14, 27, 16, 17, 25, 26];
        enum int cSyncPin = 26;

        alias font = Font!();

        enum string wifiSsid = "Zeus WPI";
        enum string wifiPassword = "zeusisdemax";

        enum ushort pongTcpServerPort = 777;
    }

    private TaskHandle_t m_loopTask;

    private FrameBufferInterrupt!(Config.vt, Config.lineBufferCount) m_fb;
    private I2SSignalGenerator!(Config.i2sIndex, Config.bitCount, Config.vt.pixelClock, true) m_i2sSignalGenerator;
    private DMADescriptorRing m_dmaDescriptorRing;

    private InterruptDrawer m_interruptDrawer;
    private FullscreenLog!(Config.vt.h.res, Config.vt.v.res, Config.font) m_fullscreenLog;
    private bool m_fullscreenLogActive;
    private WifiClient m_wifiClient;
    private Pong m_pong;

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

        logAll!"Initializing I2SSignalGenerator";
        m_i2sSignalGenerator.initialize(m_loopTask);

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
        UniqueHeapArray!Signal signals = m_i2sSignalGenerator.getSignals;
        route(from: signals.get[0], to: GPIOPin(14), invert: false); // White
        route(from: signals.get[1], to: GPIOPin(27), invert: false); // White
        route(from: signals.get[2], to: GPIOPin(16), invert: false); // White
        route(from: signals.get[3], to: GPIOPin(17), invert: false); // White
        route(from: signals.get[4], to: GPIOPin(25), invert: false); // White
        route(from: signals.get[5], to: GPIOPin(26), invert: false); // White
        route(from: signals.get[7], to: GPIOPin(12), invert: true ); // CSync
        // dfmt on

        logAll!"Starting VGA output";
        m_i2sSignalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

        logAll!"Initializing FullscreenLog";
        // m_fullscreenLog = FullscreenLog(m_fb);
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

        // long lines;
        // long totalIdleTime;
        // long totalDrawTime;

        while (true)
        {
            // long idleStartTime = esp_timer_get_time;

            // dfmt off
            const size_t currDescAddr = ulTaskGenericNotifyTake(
                uxIndexToWaitOn: 0,
                xClearCountOnExit: true,
                xTicksToWait: 10_000,
            );
            // dfmt on

            // if (currY != 8)
            //     totalIdleTime += esp_timer_get_time - idleStartTime;

            // log.info!"===";
            // log.info!"Dumping i2s regs";
            // for (int i = 0; i < 0x64; i += 4)
            //     log.info!"%x:\t%p"(i, volatileLoad(cast(uint*)(REG_I2S_BASE!(Config.i2sIndex) + i)));
            // log.info!"Dumping descriptor addresses";
            // foreach (i, ref lldesc_t desc; m_dmaDescriptorRing.descriptors)
            //     log.info!"%d:\t%p"(i, &desc);

            // long drawStartTime = esp_timer_get_time;

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

            foreach (drawY; currY + 8 .. currY + 16)
            {
                drawY %= Config.vt.v.res;
                m_interruptDrawer.drawLine(
                    m_fb.getLine(drawY),
                    drawY,
                    0,
                );
            }

            // if (currY != 8)
            //     totalDrawTime += esp_timer_get_time - drawStartTime;
            // if (currY != 8)
            //     lines += 8;
            // if (lines % 10_000 == 0)
            // {
            //     log.info!"line %lld: avgIdle=%llf avgDraw=%llf"(
            //         lines,
            //         1.0 * totalIdleTime / lines,
            //         1.0 * totalDrawTime / lines,
            //     );
            // }
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
