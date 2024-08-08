module app.vga.framebuffer.base;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import idfd.log : Logger;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:

abstract
class FrameBuffer
{
nothrow @nogc:
pragma(inline, true):
    enum log = Logger!"FrameBuffer"();

    protected immutable(VideoTimings)* m_vt;
    protected Color[][] m_allBuffers; /// Cycically looping this array produces the video signal
    protected Color[][] m_activeLineBuffers; /// The active parts of m_allBuffers, has dimensions `activeHeight * activeWidth`

    this(immutable(VideoTimings)* vt)
    in (vt !is null)
    {
        m_vt = vt;
    }

    ~this()
    {
    }

scope:
    final pure
    size_t activeWidth() const
        => m_vt.h.res;

    final pure
    size_t activeHeight() const
        => m_vt.v.res;

    final pure
    Color[][] allBuffers()
        => m_allBuffers;

    final pure
    Color[][] activeLineBuffers()
        => m_activeLineBuffers;

    // in (y < m_vt.v.res)
    final pure
    Color[] getLine(in size_t y)
        => m_activeLineBuffers[y];

    final pure
    Color[] opIndex(in size_t y)
        => getLine(y);

    // in (x < m_vt.h.res)
    final pure
    ref Color opIndex(in size_t y, in size_t x)
        => getLine(y)[x ^ 2];

    pure
    size_t opDollar(size_t dim : 0)() const
        => activeHeight;

    pure
    size_t opDollar(size_t dim : 1)() const
        => activeWidth;

    final pure
    void fill(Color color)
    {
        for (size_t y = 0; y < m_vt.v.res; y++)
            getLine(y)[] = color;
    }

    final pure
    void clear()
        => fill(Color.BLACK);

    abstract pure
    void fullClear();
}
