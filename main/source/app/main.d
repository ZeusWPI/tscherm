module app.main;

import app.http : HttpServer;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.draw : Drawer;
import app.vga.framebuffer : FrameBuffer;
import app.vga.video_timings;

import idf.freertos : vTaskDelay, vTaskSuspend;

import idfd.log : Logger;
import idfd.net.wifi_client : WiFiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;

import ministd.typecons : UniqueHeapArray;

// dfmt off
@safe:

struct TSchermRTConfig
{
    const(VideoTimings) vt;
    int redPin, greenPin, bluePin, hSyncPin, vSyncPin;
    string ssid, password;
    ushort httpPort;
}

struct TSchermCTConfig
{
}

struct TScherm(TSchermCTConfig ctConfig)
{
    private enum log = Logger!"TScherm"();

    private const TSchermRTConfig m_rtConfig;
    private FrameBuffer m_fb;
    private DMADescriptorRing m_dmaDescriptorRing;
    private I2SSignalGenerator m_signalGenerator;
    // private Drawer m_drawer;
    // private WiFiClient m_wifiClient;
    // private HttpServer m_httpServer;

    this(const TSchermRTConfig rtConfig)
    {
        m_rtConfig = rtConfig;

        // Init network async
        {
            // m_wifiClient = WiFiClient(rtConfig.ssid, rtConfig.password);
            // m_wifiClient.startAsync;
        }

        // Init VGA
        {
            m_fb = FrameBuffer(m_rtConfig.vt);
            m_signalGenerator = I2SSignalGenerator(
                i2sIndex: 1,
                bitCount: 8,
                freq: m_rtConfig.vt.pixelClock,
            );
            m_dmaDescriptorRing = DMADescriptorRing(m_rtConfig.vt.v.total);
            m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.linesWithSync)());

            UniqueHeapArray!Signal signals = m_signalGenerator.getSignals;
            // route(from: signals.get[0], to: GPIOPin(m_rtConfig.redPin  ), invert: false); // Red
            // route(from: signals.get[1], to: GPIOPin(m_rtConfig.greenPin), invert: false); // Green
            // route(from: signals.get[2], to: GPIOPin(m_rtConfig.bluePin ), invert: false); // Blue
            // route(from: signals.get[6], to: GPIOPin(m_rtConfig.hSyncPin), invert: false); // HSync
            // route(from: signals.get[7], to: GPIOPin(m_rtConfig.vSyncPin), invert: false); // VSync

            route(from: signals.get[0], to: GPIOPin(25), invert: false); // White
            route(from: signals.get[6], to: GPIOPin(26), invert: true ); // CSync

            m_signalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

            // m_drawer = Drawer(&m_fb);

            log.info!"VGA initialization complete";
        }

        // Wait for async network init to complete
        {
            // m_wifiClient.waitForConnection;

            // log.info!"Network initialization complete";
        }

        {
            // m_httpServer = HttpServer(&m_drawer, m_rtConfig.httpPort);
            // m_httpServer.start;
        }
    }

    void drawImage(string source)()
    {
        immutable ubyte[] img = cast(immutable ubyte[]) import(source);
        m_fb.drawGrayscaleImage(img, Color.YELLOW, Color.BLACK);
    }
}

extern(C)
void app_main()
{
    enum TSchermCTConfig ctConfig = TSchermCTConfig();
    const TSchermRTConfig rtConfig = TSchermRTConfig(
        vt: VIDEO_TIMINGS_640W_480H_MAC,
        redPin: 14,
        greenPin: 27,
        bluePin: 16,
        hSyncPin: 25,
        vSyncPin: 26,
        ssid: "Zeus WPI",
        password: "zeusisdemax",
        httpPort: 80,
    );
    auto tScherm = TScherm!ctConfig(rtConfig);


    while (true)
    {
        auto pause = (int t) @trusted => vTaskDelay(t);

        tScherm.m_fb.fill(Color.WHITE);
        pause(200);

        tScherm.drawImage!"zeus.raw";
        pause(800);
        tScherm.drawImage!"reavershark.raw";
        pause(800);

        tScherm.m_fb.fillIteratingColorsDiagonal!"x+y/vDivide";
        pause(200);
        tScherm.m_fb.fillIteratingColorsDiagonal!"(x+y/vDivide) / 2";
        pause(200);

        tScherm.m_fb.fill(Color.BLACK);
        pause(200);
    }

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
