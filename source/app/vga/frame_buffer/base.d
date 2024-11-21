module app.vga.frame_buffer.base;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import idfd.log : Logger;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:

abstract
class FrameBuffer(VideoTimings ct_vt)
{
nothrow @nogc:
pragma(inline, true):
    enum log = Logger!"FrameBuffer"();

    protected Color[][] m_allBuffers; /// Cycically looping this array produces the video signal
    protected Color[][] m_activeLineBuffers; /// The active parts of m_allBuffers, has dimensions `activeHeight * activeWidth`

    this()
    {
    }

    @disable this(ref typeof(this));

    ~this()
    {
    }

scope:
    final pure
    size_t activeWidth() const
        => ct_vt.h.res;

    final pure
    size_t activeHeight() const
        => ct_vt.v.res;

    pure
    size_t opDollar(size_t dim : 0)() const
        => activeHeight;

    pure
    size_t opDollar(size_t dim : 1)() const
        => activeWidth;

    final pure
    Color[][] allBuffers()
        => m_allBuffers;

    final pure
    Color[][] activeLineBuffers()
        => m_activeLineBuffers;

    final pure
    Color[] getLine(in size_t y)
        => m_activeLineBuffers[y];

    final pure
    Color[] opIndex(in size_t y)
        => getLine(y);

    final pure
    ref Color opIndex(in size_t y, in size_t x)
        => getLine(y)[x ^ 2];

    pure
    void fill(Color color)
    {
        for (size_t y = 0; y < ct_vt.v.res; y++)
            m_activeLineBuffers[y][] = color;
    }

    final pure
    void clear()
        => fill(Color.BLACK);

    abstract pure
    void fullClear();
}
