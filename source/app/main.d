module app.main;

import app.pong.pong : Pong;
import app.fullscreen_log : FullscreenLog;
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

extern (C) void _d_callfinalizer(void* ptr)
{
}

extern (C)
void app_main()
{
    enum log = Logger!"main"();

    struct Config
    {
        static const VideoTimings vt = VIDEO_TIMINGS_320W_480H_MAC;
        alias FrameBufferImpl = FrameBufferRegularVDiv!1;

        enum int whitePin = 25;
        enum int cSyncPin = 26;

        enum string wifiSsid = "Zeus WPI";
        enum string wifiPassword = "zeusisdemax";

        enum ushort pongTcpServerPort = 777;
    }

    log.info!("Initializing " ~ Config.FrameBufferImpl.stringof);
    scope fb = new Config.FrameBufferImpl(Config.vt);

    log.info!"Initializing FullscreenLog";
    FullscreenLog fullscreenLog = FullscreenLog(fb);

    fullscreenLog.writeln("Initializing I2SSignalGenerator");
    // dfmt off
    I2SSignalGenerator signalGenerator = I2SSignalGenerator(
        i2sIndex: 1,
        bitCount: 8,
        freq: Config.vt.pixelClock,
    );
    // dfmt on

    fullscreenLog.writeln("Initializing DMADescriptorRing");
    DMADescriptorRing dmaDescriptorRing = DMADescriptorRing(Config.vt.v.total);
    dmaDescriptorRing.setBuffers((() @trusted => cast(ubyte[][]) fb.linesWithSync)());

    fullscreenLog.writeln("Routing GPIO signals");
    UniqueHeapArray!Signal signals = signalGenerator.getSignals;
    // dfmt off
    route(from: signals.get[0], to: GPIOPin(Config.whitePin), invert: false); // White
    route(from: signals.get[6], to: GPIOPin(Config.cSyncPin), invert: true ); // CSync
    // dfmt on

    fullscreenLog.writeln("Starting VGA output");
    signalGenerator.startTransmitting(dmaDescriptorRing.firstDescriptor);

    fullscreenLog.writeln("Initializing WifiClient (async)");
    WiFiClient wifiClient = WiFiClient(Config.wifiSsid, Config.wifiPassword);
    wifiClient.startAsync;

    fullscreenLog.writeln("Connecting to AP with ssid: " ~ Config.wifiSsid);
    wifiClient.waitForConnection;

    fullscreenLog.clear;
    fullscreenLog.writeln("Connected to " ~ Config.wifiSsid ~ "!");
    (() @trusted => vTaskDelay(100))();

    fullscreenLog.writeln("Starting Pong");
    (() @trusted => vTaskDelay(100))();
    Pong pong = Pong(fb);

    while (true)
    {
        (() @trusted => vTaskSuspend(null))();
    }
}
