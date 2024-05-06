module app.main;

import app.vga.color : Color;
import app.vga.dma_descriptor_ring : DMADescriptorRing;
import app.vga.framebuffer : FrameBuffer;
import app.vga.video_timings : VideoTimings, VIDEO_TIMINGS_320W_480H;

import idfd.net.tcp : tcp_client;
import idfd.net.wifi_client : WiFiClient;
import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.i2s : I2SSignalGenerator;
import idfd.signalio.router : route;
import idfd.signalio.signal : Signal;
import idfd.util;

import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : vTaskDelay, vTaskSuspend;
import idf.heap.caps : MALLOC_CAP_DMA;
import idf.stdio : printf;

// dfmt off
@safe:

struct TSchermRTConfig
{
    const(VideoTimings) vt;
    int redPin, greenPin, bluePin, hSyncPin, vSyncPin;
    string ssid, password;
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

    this(const TSchermRTConfig rtConfig)
    {
        m_rtConfig = rtConfig;

        // Init network async
        {
            m_wifiClient = WiFiClient(rtConfig.ssid, rtConfig.password);
            m_wifiClient.startAsync;
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

        // Wait for async network init to complete
        {
            m_wifiClient.waitForConnection;

            printf("Network initialization complete\n");
        }
    }

    void drawZeusImage()
    {
        immutable ubyte[] zeusImage = cast(immutable ubyte[]) import("zeus.raw");
        m_fb.drawGrayscaleImage(zeusImage, Color.YELLOW, Color.BLACK);
    }

    void connectTCP() @trusted
    {
        string ip = "10.0.0.130";
        ushort port = 1234;

        import idf.sys.socket :
            socket, connect, send, recv, close,
            sockaddr, sockaddr_in,
            inet_pton, htons,
            AF_INET, SOCK_STREAM, IPPROTO_IP;

        sockaddr_in addr;
        {
            addr.sin_family = AF_INET;

            UniqueHeapArray!char ipStringz = ip.toStringz;
            inet_pton(AF_INET, &ipStringz.get[0], &addr.sin_addr);

            addr.sin_port = htons(port);
        }

        outer_loop:
        while (true)
        {
            int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
            assert(sock);
            scope(exit) close(sock);

            if (connect(sock, cast(sockaddr*) &addr, addr.sizeof) != 0)
            {
                printf("Failed to connect, retrying soon...\n");
                vTaskDelay(50);
                continue;
            }

            {
                enum msg = "Send image (320*480 bytes)\n";
                int sent = send(sock, &msg[0], msg.length, 0);
                if (sent != msg.length)
                {
                    printf("send failed, reconnecting...\n");
                    continue outer_loop;
                }
                printf("Sent %ld bytes\n", sent);
            }

            foreach (y; 0 .. m_rtConfig.vt.v.res)
                foreach (x; 0 .. m_rtConfig.vt.h.res)
                {
                    ubyte[1] buf;
                    while (recv(sock, &buf[0], buf.length, 0) != buf.length)
                    {
                        printf("A recv failed...\n");
                        vTaskDelay(1);
                    }
                    m_fb[y, x] = buf[0] >= 0x80 ? Color.WHITE : Color.BLACK;
                }

            {
                enum msg = "Image fully received\n";
                int sent = send(sock, &msg[0], msg.length, 0);
                assert(sent == msg.length);
                if (sent != msg.length)
                {
                    printf("send failed, reconnecting...\n");
                    continue outer_loop;
                }
                printf("Sent %ld bytes\n", sent);
            }
        }
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
    );
    auto tScherm = TScherm!ctConfig(rtConfig);

    tScherm.drawZeusImage;
    tScherm.connectTCP;

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
