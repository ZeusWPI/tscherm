module app.main;

import app.pong.pong : Pong;
import app.singleton : Singleton;
import app.text_view : TextView;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.font : FontMC16x32;
import app.vga.frame_buffer.frame_buffer_n_line_buffers : FrameBufferNLineBuffers;
import app.vga.video_timings;

import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : pdPASS, TaskHandle_t, ulTaskGenericNotifyTake, vTaskDelay, vTaskSuspend, xTaskCreatePinnedToCore;

import idfd.log : Logger;
import idfd.net.wifi_client : WifiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;

import ministd.algorithm : min;
import ministd.typecons : UniqueHeap, UniqueHeapArray;

@safe:

struct TScherm
{
    enum log = Logger!"TScherm"();

    struct Config
    {
        enum VideoTimings vt = VIDEO_TIMINGS_640W_480H_MAC;

        enum size_t lineBufferCount = 8;
        enum size_t drawBatchSize = 4;

        enum uint i2sIndex = 1;
        enum uint bitCount = 8;

        enum int[] colorPins = [12, 14, 27, 26, 25, 33, 32];
        enum int cSyncPin = 13;
        enum int pinUp = 22;
        enum int pinDown = 23;

        alias FontT = FontMC16x32;

        enum string wifiSsid = "Zeus WPI";
        enum string wifiPassword = "zeusisdemax";

        enum int coreCount = 2;

        alias FrameBufferT = FrameBufferNLineBuffers!(vt, lineBufferCount);

        static assert(lineBufferCount % drawBatchSize == 0);
        static assert(drawBatchSize <= lineBufferCount / 2);
        static assert(0 < coreCount && coreCount <= 2);
    }

    private
    struct LoopTaskArg
    {
        int core;
    }

    private __gshared bool s_instanceInitialized;
    private __gshared TScherm s_instance;

    private UniqueHeap!(Config.FrameBufferT) m_fb;
    private I2SSignalGenerator!(Config.i2sIndex, Config.bitCount, Config.vt.pixelClock, false) m_i2sSignalGenerator;
    private DMADescriptorRing m_dmaDescriptorRing;

    private Config.FontT m_font;
    private TextView!(Config.vt.h.res, Config.vt.v.res, Config.FontT) m_fullScreenLog;
    private bool m_fullScreenLogInitialized;

    private WifiClient m_wifiClient;

    private Pong!(Config.vt.h.res, Config.vt.v.res, Config.pinUp, Config.pinDown, Config.FontT) m_pong;
    private bool m_pongInitialized;

    private LoopTaskArg[Config.coreCount] m_loopTaskArgs;
    private TaskHandle_t[Config.coreCount] m_loopTasks;

    static @trusted
    void createInstance()
    in (!s_instanceInitialized)
    {
        s_instanceInitialized = true;
        s_instance.initialize;
    }

    static @trusted nothrow @nogc
    ref TScherm instance()
    in (s_instanceInitialized)
        => s_instance;

    @disable this();
    @disable this(ref typeof(this));

    private
    void initialize()
    {
        log.info!"Initializing FrameBuffer";
        m_fb = typeof(m_fb).create;

        log.info!"Initializing DMADescriptorRing";
        m_dmaDescriptorRing.initialize(m_fb.allBuffers.length);
        m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.allBuffers)());

        log.info!"Initializing I2SSignalGenerator";
        m_i2sSignalGenerator.initialize();

        log.info!"Setting descriptor eof flags";
        // Ex. for drawBatchSize 8, will trigger interrupts after reading
        //   res descriptors 15, 31, ...
        //   or active descriptors 7, 15, ...
        // dfmt off
        for (
            size_t i = Config.vt.v.resStart + Config.drawBatchSize * 2 - 1;
            i < Config.vt.v.resStart + Config.vt.v.res * 2;
            i += Config.drawBatchSize * 2
        )
            m_dmaDescriptorRing.descriptors[i].eof = 1;
        // dfmt on

        // dfmt off
        log.info!"Routing GPIO signals";
        UniqueHeapArray!Signal signals = m_i2sSignalGenerator.getSignals;
        static foreach(i, int pin; Config.colorPins)
            route(from: signals.get[i], to: GPIOPin(pin), invert: false);
        route(from: signals.get[$ - 1], to: GPIOPin(Config.cSyncPin), invert: true);
        // dfmt on

        log.info!"Starting VGA output";
        m_i2sSignalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

        log.info!"Initializing Font";
        m_font.initialize;

        log.info!"Initializing a TextView as fullscreen log";
        (() @trusted => m_fullScreenLog.initialize(&m_font))();
        m_fullScreenLogInitialized = true;

        log.info!"Initializing WifiClient (async)";
        m_wifiClient = WifiClient(Config.wifiSsid, Config.wifiPassword);
        m_wifiClient.startAsync;

        log.info!("Connecting to AP with ssid: " ~ Config.wifiSsid);
        m_fullScreenLog.writeln("Connecting to AP with ssid: " ~ Config.wifiSsid);
        m_wifiClient.waitForConnection;

        log.info!("Connected to " ~ Config.wifiSsid ~ "!");
        m_fullScreenLog.writeln("Connected to " ~ Config.wifiSsid ~ "!");
        vTaskDelay(500);

        log.info!"Creating loop tasks";
        // dfmt off
        static foreach (int core; 0 .. Config.coreCount)
        {{
            enum string name = core == 0 ? "loop_0" : "loop_1";
            m_loopTaskArgs[core].core = core;
            (() @trusted {
                auto result = xTaskCreatePinnedToCore(
                    pvTaskCode: &TScherm.loopTaskEntrypoint,
                    pcName: name,
                    usStackDepth: 4000,
                    pvParameters: &m_loopTaskArgs[core],
                    uxPriority: 10,
                    pvCreatedTask: &m_loopTasks[core],
                    xCoreID: core,
                );
                assert(result == pdPASS);
            })();
        }}
        // dfmt on

        log.info!"Starting Pong";
        m_fullScreenLog.writeln("Starting Pong");
        vTaskDelay(2000);
        (() @trusted => m_pong.initialize(&m_font))();
        m_pongInitialized = true;
    }

    private static @trusted extern (C)
    void loopTaskEntrypoint(void* loopTaskArgVoidPtr)
        => TScherm.instance.loop(cast(LoopTaskArg*) loopTaskArgVoidPtr);

    private @trusted
    void loop(LoopTaskArg* loopTaskArg)
    {
        log.info!"Loop task %d entrypoint"(loopTaskArg.core);

        const size_t firstDescAddr = cast(size_t) m_dmaDescriptorRing.firstDescriptor;
        uint lastDrawYStart;

        while (true)
        {
            if (m_pongInitialized)
            {
                // m_pong.tickIfReady;
            }

            const uint currDescAddr = m_i2sSignalGenerator.currDescAddr;

            const size_t currDescIndex = (currDescAddr - firstDescAddr) / lldesc_t.sizeof;

            if (!(Config.vt.v.resStart <= currDescIndex && currDescIndex < Config.vt.v.resStart + Config.vt.v.res * 2))
                continue;
            const uint currY = (currDescIndex - Config.vt.v.resStart) / 2;

            uint drawYStart = (currY + Config.drawBatchSize + 1) % Config.vt.v.res;
            drawYStart -= (drawYStart % Config.drawBatchSize);

            if (drawYStart == lastDrawYStart)
                continue;

            foreach (drawY; drawYStart .. min(drawYStart + Config.drawBatchSize, Config.vt.v.res))
            {
                if (drawY % Config.coreCount != loopTaskArg.core)
                    continue;

                Color[] line = m_fb.getLine(drawY);

                if (m_pongInitialized)
                {
                    // m_pong.drawLine(line, drawY);
                    for (ushort x = Config.vt.h.res; x < Config.vt.h.res; x++)
                        line[x ^ 2] = Color((drawY + x) % 0x80);
                }
                else if (m_fullScreenLogInitialized)
                {
                    m_fullScreenLog.drawLine(line, drawY);
                }
                else
                {
                    line[] = Color.BLACK;
                }
            }

            lastDrawYStart = drawYStart;
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
