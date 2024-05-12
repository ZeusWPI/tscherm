module app.main;

import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.framebuffer : FrameBuffer;
import app.vga.video_timings : VideoTimings, VIDEO_TIMINGS_320W_480H;

import idfd.net.http : HttpServer;
import idfd.net.wifi_client : WiFiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;

import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : vTaskDelay, vTaskSuspend;
import idf.heap.caps : MALLOC_CAP_DMA;
import idf.stdio : printf;

import ministd.memory : UniqueHeapArray;

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
    const TSchermRTConfig m_rtConfig;
    FrameBuffer m_fb;
    DMADescriptorRing m_dmaDescriptorRing;
    I2SSignalGenerator m_signalGenerator;
    WiFiClient m_wifiClient;
    HttpServer m_httpServer;

    this(const TSchermRTConfig rtConfig)
    {
        m_rtConfig = rtConfig;

        // Init network async
        {
            m_wifiClient = WiFiClient(rtConfig.ssid, rtConfig.password);
            m_wifiClient.startAsync;
        }

        // Wait for async network init to complete
        {
            m_wifiClient.waitForConnection;

            printf("Network initialization complete\n");
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
            route(from: signals.get[0], to: GPIOPin(m_rtConfig.redPin));   // Red
            route(from: signals.get[1], to: GPIOPin(m_rtConfig.greenPin)); // Green
            route(from: signals.get[2], to: GPIOPin(m_rtConfig.bluePin));  // Blue
            route(from: signals.get[6], to: GPIOPin(m_rtConfig.hSyncPin)); // HSync
            route(from: signals.get[7], to: GPIOPin(m_rtConfig.vSyncPin)); // VSync

            m_signalGenerator.startTransmitting(m_dmaDescriptorRing.firstDescriptor);

            printf("VGA initialization complete\n");
        }

        {
            m_httpServer = HttpServer(m_rtConfig.httpPort);
            m_httpServer.start;
        }
    }

    void drawZeusImage()
    {
        immutable ubyte[] zeusImage = cast(immutable ubyte[]) import("zeus.raw");
        m_fb.drawGrayscaleImage(zeusImage, Color.YELLOW, Color.BLACK);
    }
}

extern(C) void app_main()
{
    enum TSchermCTConfig ctConfig = TSchermCTConfig();
    const TSchermRTConfig rtConfig = TSchermRTConfig(
        vt: VIDEO_TIMINGS_320W_480H,
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

    tScherm.drawZeusImage;

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
