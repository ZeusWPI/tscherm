module app.vga.video_timings;

// dfmt off
@safe nothrow @nogc:

struct VideoTimings
{
    struct Dimension
    {
        uint res, front, sync, back;
        uint total() const pure => res + front + sync + back;
        uint resStart() const pure => 0;
        uint resEnd() const pure => res;
        uint frontStart() const pure => res;
        uint frontEnd() const pure => res + front;
        uint syncStart() const pure => res + front;
        uint syncEnd() const pure => res + front + sync;
        uint backStart() const pure => res + front + sync;
        uint backEnd() const pure => res + front + sync + back;
    }

    ulong pixelClock;
    Dimension h;
    Dimension v;
}

enum VideoTimings VIDEO_TIMINGS_320W_480H = {
    pixelClock: 12_587_500,
    h: {res: 320, front: 8, sync: 48, back: 24},
    v: {res: 480, front: 11, sync: 2, back: 31},
};

enum VideoTimings VIDEO_TIMINGS_640W_480H = {
    pixelClock: 25_175_000,
    h: {res: 640, front: 16, sync: 96, back: 48},
    v: {res: 480, front: 10, sync: 2, back: 33},
};

enum VideoTimings VIDEO_TIMINGS_1280W_720H = {
    pixelClock: 74_250_000,
    h: {res: 1280, front: 110, sync: 40, back: 220},
    v: {res: 720, front: 5, sync: 5, back: 20},
};
