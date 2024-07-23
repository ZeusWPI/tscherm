module app.vga.video_timings;

@safe nothrow @nogc:
// dfmt off

struct VideoTimings
{
    struct Dimension
    {
const pure nothrow @nogc:
        uint front, sync, back, res;
        uint total() => front + sync + back + res;
        uint frontStart() => 0;
        uint frontEnd() => front;
        uint syncStart() => front;
        uint syncEnd() => front + sync;
        uint backStart() => front + sync;
        uint backEnd() => front + sync + back;
        uint resStart() => front + sync + back;
        uint resEnd() => front + sync + back + res;
    }

    ulong pixelClock;
    Dimension h;
    Dimension v;
}

enum VideoTimings VIDEO_TIMINGS_320W_480H = {
    pixelClock: 25_175_000/2,
    h: {res: 640/2, front: 16/2, sync: 96/2, back: 48/2},
    v: {res: 480, front: 11, sync: 2, back: 31},
};

enum VideoTimings VIDEO_TIMINGS_640W_480H_MAC = {
    // min: 27_125_000
    // recommended: 30_240_000
    pixelClock: 30_240_000,
    h: {front: 64, sync: 64, back: 96, res: 640},
    v: {front: 3,  sync: 3,  back: 39, res: 480},
};

enum VideoTimings VIDEO_TIMINGS_640W_480H = {
    pixelClock: 25_175_000,
    h: {front: 16, sync: 96, back: 48, res: 640},
    v: {front: 10, sync: 2,  back: 33, res: 480},
};

enum VideoTimings VIDEO_TIMINGS_1280W_720H = {
    pixelClock: 74_250_000,
    h: {res: 1280, front: 110, sync: 40, back: 220},
    v: {res: 720, front: 5, sync: 5, back: 20},
};
