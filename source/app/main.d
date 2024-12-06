module app.main;

import app.pannenkoeken_wachtrij.pannenkoeken_wachtrij : PannenkoekenWachtrij;
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

        enum size_t lineBufferCount = 32;
        enum size_t drawBatchSize = 16;

        enum uint i2sIndex = 1;
        enum uint bitCount = 8;

        enum int[] colorPins = [12, 14, 27, 26, 25, 33, 32];
        enum int cSyncPin = 13;

        alias FontT = FontMC16x32;

        enum string wifiSsid = "Zeus WPI";
        enum string wifiPassword = "zeusisdemax";

        alias FrameBufferT = FrameBufferNLineBuffers!(vt, lineBufferCount);
        alias PannenkoekenWachtrijT = PannenkoekenWachtrij!(Config.vt.h.res, Config.vt.v.res, FontT);

        static assert(lineBufferCount % drawBatchSize == 0);
        static assert(drawBatchSize <= lineBufferCount / 2);
    }

    private __gshared bool s_instanceInitialized;
    private __gshared TScherm s_instance;

    private TaskHandle_t m_loopTask;

    private UniqueHeap!(Config.FrameBufferT) m_fb;
    private I2SSignalGenerator!(Config.i2sIndex, Config.bitCount, Config.vt.pixelClock, true) m_i2sSignalGenerator;
    private DMADescriptorRing m_dmaDescriptorRing;

    private Config.FontT m_font;
    private TextView!(Config.vt.h.res, Config.vt.v.res, Config.FontT) m_fullScreenLog;
    private bool m_fullScreenLogInitialized;

    private WifiClient m_wifiClient;

    private UniqueHeap!(Config.PannenkoekenWachtrijT) m_pannenkoekenWachtrij;
    private bool m_pannenkoekenWachtrijInitialized;

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
        log.info!"Creating loop task";
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

        log.info!("Initializing FrameBuffer");
        m_fb = typeof(m_fb).create;

        log.info!"Initializing DMADescriptorRing";
        m_dmaDescriptorRing = DMADescriptorRing(m_fb.allBuffers.length);
        m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.allBuffers)());

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

        log.info!"Initializing I2SSignalGenerator";
        m_i2sSignalGenerator.initialize(m_loopTask);

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

        log.info!"Starting PannenkoekenWachtrij";
        m_fullScreenLog.writeln("Starting PannenkoekenWachtrij");
        vTaskDelay(500);
        m_pannenkoekenWachtrij = (() @trusted => typeof(m_pannenkoekenWachtrij).create(&m_font))();
        m_pannenkoekenWachtrijInitialized = true;
    }

    private static @trusted extern (C)
    void loopTaskEntrypoint(void* ignore)
        => TScherm.instance.loop;

    private @trusted
    void loop()
    {
        // The first log from this task seems to take 0.5ms extra, so get it out of the way
        log.info!"Loop task entrypoint";

        while (true)
        {
            // dfmt off
            const size_t currDescAddr = ulTaskGenericNotifyTake(
                uxIndexToWaitOn: 0,
                xClearCountOnExit: true,
                xTicksToWait: 10,
            );
            // dfmt on

            if (!currDescAddr)
                continue;

            const size_t firstDescAddr = cast(size_t) m_dmaDescriptorRing.firstDescriptor;

            assert(currDescAddr >= firstDescAddr);
            assert((currDescAddr - firstDescAddr) % lldesc_t.sizeof == 0);
            const size_t currDescIndex = (currDescAddr - firstDescAddr) / lldesc_t.sizeof;

            if (!(Config.vt.v.resStart <= currDescIndex && currDescIndex < Config.vt.v.resStart + Config.vt.v.res * 2))
                continue;

            uint currY = (currDescIndex - Config.vt.v.resStart) / 2;
            uint drawYStart = (currY + Config.drawBatchSize + 1) % Config.vt.v.res;
            drawYStart -= (drawYStart % Config.drawBatchSize);

            foreach (drawY; drawYStart .. min(drawYStart + Config.drawBatchSize, Config.vt.v.res))
            {
                Color[] line = m_fb.getLine(drawY);

                if (m_pannenkoekenWachtrijInitialized)
                {
                    m_pannenkoekenWachtrij.drawLine(line, drawY);
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
