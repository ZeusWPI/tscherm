module app.main;

import app.http : HttpServer;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.draw : Drawer;
import app.vga.framebuffer;
import app.vga.video_timings;

import idf.freertos : vTaskDelay, vTaskSuspend;

import idfd.log : Logger;
import idfd.net.wifi_client : WiFiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;

import ministd.typecons : UniqueHeap, UniqueHeapArray;

@safe:

struct TSchermRTConfig
{
    const(VideoTimings) vt;
    int whitePin, cSyncPin;
    string ssid, password;
    ushort httpPort;
}

struct TSchermCTConfig
{
}

struct TScherm(TSchermCTConfig ctConfig)
{
    private
    {
        enum log = Logger!"TScherm"();

        const TSchermRTConfig m_rtConfig;
        UniqueHeap!FrameBufferRegularVDiv m_fb;
        DMADescriptorRing m_dmaDescriptorRing;
        I2SSignalGenerator m_signalGenerator;
        Drawer m_drawer;
        WiFiClient m_wifiClient;
        HttpServer m_httpServer;
    }

scope:
    this(const TSchermRTConfig rtConfig)
    {
        m_rtConfig = rtConfig;

        {
            log.info!"Initializing network (async)";

            m_wifiClient = WiFiClient(rtConfig.ssid, rtConfig.password);
            m_wifiClient.startAsync;
        }

        {
            log.info!"Initializing VGA";

            m_fb = typeof(m_fb).create(m_rtConfig.vt);
            // dfmt off
            m_signalGenerator = I2SSignalGenerator(
                i2sIndex: 1,
                bitCount: 8,
                freq: m_rtConfig.vt.pixelClock,
            );
            // dfmt on
            m_dmaDescriptorRing = DMADescriptorRing(m_rtConfig.vt.v.total);
            m_dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) m_fb.linesWithSync)());

            UniqueHeapArray!Signal signals = m_signalGenerator.getSignals;
            // dfmt off
            route(from: signals.get[0], to: GPIOPin(m_rtConfig.whitePin), invert: false); // White
            route(from: signals.get[6], to: GPIOPin(m_rtConfig.cSyncPin), invert: true ); // CSync
            // dfmt on

            m_signalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

            m_drawer = Drawer(m_fb.get);

            log.info!"VGA initialization complete";
        }

        {
            log.info!"Waiting for network to initialize";

            m_wifiClient.waitForConnection;

            log.info!"Network initialization complete";
        }

        {
            log.info!"Starting http server (in another task)";

            m_httpServer = HttpServer(&m_drawer, m_rtConfig.httpPort);
            m_httpServer.start;
        }
    }

    void drawImage(string source)()
    {
        immutable ubyte[] img = cast(immutable ubyte[]) import(source);
        m_fb.drawGrayscaleImage(img, Color.YELLOW, Color.BLACK);
    }
}

extern (C)
void app_main()
{
    enum log = Logger!"main"();

    // dfmt off
    enum TSchermCTConfig ctConfig = TSchermCTConfig();
    const TSchermRTConfig rtConfig = TSchermRTConfig(
        vt: VIDEO_TIMINGS_640W_480H_MAC,
        whitePin: 25,
        cSyncPin: 26,
        ssid: "Zeus WPI",
        password: "zeusisdemax",
        httpPort: 80,
    );
    // dfmt on
    auto tScherm = TScherm!ctConfig(rtConfig);

    log.info!"Rotating between some patterns";
    while (true)
    {
        auto pause = (int t) @trusted => vTaskDelay(t);

        tScherm.m_fb.fill(Color.WHITE);
        pause(200);

        // tScherm.drawImage!"zeus.raw";
        // pause(800);
        // tScherm.drawImage!"reavershark.raw";
        // pause(800);

        tScherm.m_fb.fillIteratingColorsDiagonal!"x+y/vDivide";
        pause(200);
        tScherm.m_fb.fillIteratingColorsDiagonal!"(x+y/vDivide) / 2";
        pause(200);

        tScherm.m_fb.fill(Color.BLACK);
        pause(200);

        log.info!"Completed a rotation";
    }

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
