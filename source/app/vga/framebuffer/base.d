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
    enum log = Logger!"FrameBuffer"();

    protected const VideoTimings m_vt;
    protected Color[][] m_lineBuffers;

    this(in VideoTimings vt)
    {
        m_vt = vt;
        m_lineBuffers = dallocArray!(Color[])(m_vt.v.total);
    }

    ~this()
    {
        dfree(m_lineBuffers);
    }

final scope:
    pure
    size_t activeWidth() const => m_vt.h.res;

    pure
    size_t activeHeight() const => m_vt.v.res;

    pure
    Color[][] linesWithSync() => m_lineBuffers;

    pure
    Color[] getLineWithSync(in size_t y)
    in (y < m_vt.v.total)
    {
        return m_lineBuffers[m_vt.v.resStart + y][0 .. m_vt.h.total];
    }

    pure
    Color[] getLine(in size_t y)
    in (y < m_vt.v.res)
    {
        return m_lineBuffers[m_vt.v.resStart + y][m_vt.h.resStart .. m_vt.h.resEnd];
    }

    pure
    Color[] opIndex(in size_t y)
    in (y < m_vt.v.res)
    {
        return getLine(y);
    }

    pure
    ref Color opIndex(in size_t y, in size_t x)
    in (y < m_vt.v.res)
    in (x < m_vt.h.res)
    {
        return getLine(y)[x ^ 2];
    }

    pure
    void fill(Color color)
    {
        for (size_t y = 0; y < m_vt.v.res; y++)
            getLine(y)[] = color;
    }

    pure
    void clear() => fill(Color.BLACK);
}
