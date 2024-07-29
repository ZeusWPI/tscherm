module app.main;

import app.pong.drawer;
import app.pong.tcp_server;
import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
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
    ushort pongTcpServerPort;
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
        WiFiClient m_wifiClient;
        PongDrawer m_pongDrawer;
        PongTcpServer m_pongTcpServer;
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

            log.info!"VGA initialization complete";
        }

        {
            log.info!"Waiting for network to initialize";
            m_wifiClient.waitForConnection;
            log.info!"Network initialization complete";
        }

        {
            log.info!"Initializing PongDrawer";
            m_pongDrawer = PongDrawer(m_fb);
            log.info!"PongDrawer initialized";
        }

        {
            log.info!"Starting PongTcpServer";
            m_pongTcpServer = PongTcpServer(&m_pongDrawer);
            m_pongTcpServer.start;
        }
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
        pongTcpServerPort: 777,
    );
    // dfmt on
    auto tScherm = TScherm!ctConfig(rtConfig);

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
