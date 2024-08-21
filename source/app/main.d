module app.main;

import app.text_view : TextView;
import app.pong.pong : Pong;
import app.singleton : Singleton;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.font : FontMC16x32;
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

        enum size_t lineBufferCount = 24;
        enum size_t drawBatchSize = 4;

        enum uint i2sIndex = 1;
        enum uint bitCount = 8;

        enum int[] colorPins = [26, 25, 17, 16, 27, 14, 12];
        enum int cSyncPin = 13;

        alias FontT = FontMC16x32;

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

    private Config.FontT m_font;
    private TextView!(Config.vt.h.res, Config.vt.v.res, Config.FontT) m_textView;
    private bool m_textViewInitialized;
    // private WifiClient m_wifiClient;
    // private Pong m_pong;

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
        m_fb.initialize;

        log.info!"Initializing DMADescriptorRing";
        m_dmaDescriptorRing = DMADescriptorRing(m_fb.allBuffers.length);
        m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.allBuffers)());

        log.info!"Initializing I2SSignalGenerator";
        m_i2sSignalGenerator.initialize(m_loopTask);

        log.info!"Setting descriptor eof flags";
        // dfmt off
        for (
            size_t i = Config.vt.v.resStart + Config.drawBatchSize * 2 - 1;
            i < m_dmaDescriptorRing.descriptors.length;
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

        log.info!"Initializing a TextView";
        (() @trusted => m_textView.initialize(&m_font))();
        m_textViewInitialized = true;

        m_textView.writeln("Hello Zeus WPI =))))))))");
        vTaskDelay(1000);
        m_textView.writeln;
        m_textView.writeln("More lines");
        vTaskDelay(1000);
        m_textView.writeln("Even more lines!");
        vTaskDelay(1000);

        m_textView.writeln(
            `A really really really really long line with wrapping`
                ~ ` and much more text on the next few lines.........`
                ~ ` abcdefghijklmnopqrtstuvxyz`
                ~ ` ABCDEFGHIJKLMNOPQRTSTUVXYZ`
                ~ ` 0123456789`
                ~ ` !"#$%&'()*+,-./`
                ~ ` :;<=>?@ [\]^_ {|}~`
                ~ " `"
        );

        // log.info!"Initializing WifiClient (async)";
        // m_wifiClient = WifiClient(Config.wifiSsid, Config.wifiPassword);
        // m_wifiClient.startAsync;

        // log.info!("Connecting to AP with ssid: " ~ Config.wifiSsid);
        // m_wifiClient.waitForConnection;

        // log.info!("Connected to " ~ Config.wifiSsid ~ "!");
        // (() @trusted => vTaskDelay(100))();

        // log.info!"Starting Pong";
        // (() @trusted => vTaskDelay(100))();
        // m_pong = Pong(m_fb);
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
                Color[] line = m_fb.getLine(drawY);

                if (m_textViewInitialized)
                {
                    m_textView.drawLine(line, drawY);
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
