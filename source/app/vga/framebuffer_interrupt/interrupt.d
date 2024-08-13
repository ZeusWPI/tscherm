module app.vga.framebuffer_interrupt.interrupt;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import idfd.log : Logger;

import ministd.heap_caps : dallocArrayCaps;
import ministd.algorithm : swap;

@safe nothrow @nogc:

struct FrameBufferInterrupt(size_t ct_lineBufferCount = 16)
{
nothrow @nogc:
    enum log = Logger!"FrameBufferInterrupt"();

    protected immutable(VideoTimings)* m_vt;
    protected Color[][] m_allBuffers; /// Cycically looping this array produces the video signal

    protected Color[] m_bufferVBlankLine;
    protected Color[] m_bufferVSyncLine;
    protected Color[] m_bufferHFrontSyncBack;

    protected Color[][] m_lineBuffers;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize(in immutable(VideoTimings)* vt)
    in (vt !is null)
    {
        m_vt = vt;

        assert(m_vt.v.res % ct_lineBufferCount == 0); // Vertical res must be divisible by line buffer count

        assert(m_vt.v.frontStart == 0); // Assume VideoTimings uses order: front, sync, back, res

        m_bufferVBlankLine = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_bufferVSyncLine = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_bufferHFrontSyncBack = dallocArrayCaps!Color(
            m_vt.h.front + m_vt.h.sync + m_vt.h.back, MALLOC_CAP_DMA);

        m_lineBuffers = dallocArray!(Color[])(ct_lineBufferCount);
        foreach (ref Color[] buf; m_lineBuffers)
            buf = dallocArrayCaps!Color(m_vt.h.res, MALLOC_CAP_DMA);

        // Lines with an active part use 2 buffers, the buffer for the inactive part (m_bufferHFrontSyncBack) is reused
        m_allBuffers = dallocArray!(Color[])(m_vt.v.total + m_vt.v.res);
        foreach (i, ref Color[] buf; m_allBuffers)
        {
            if (m_vt.v.syncStart <= i && i < m_vt.v.syncEnd)
                buf = m_bufferVSyncLine;
            else if (i < m_vt.v.backEnd)
                buf = m_bufferVBlankLine;
            else
            {
                size_t resBufferIndex = i - m_vt.v.front - m_vt.v.sync - m_vt.v.back;
                if (resBufferIndex % 2 == 0)
                    buf = m_bufferHFrontSyncBack;
                else
                {
                    size_t lineBufferIndex = (resBufferIndex / 2) % ct_lineBufferCount;
                    buf = m_lineBuffers[lineBufferIndex];
                }
            }
        }

        fullClear;
    }

    ~this()
    {
        if (m_allBuffers is null)
            return;

        dfree(m_allBuffers);

        dfree(m_bufferVBlankLine);
        dfree(m_bufferVSyncLine);
        dfree(m_bufferHFrontSyncBack);

        foreach (ref Color[] buf; m_lineBuffers)
            dfree(buf);
        dfree(m_lineBuffers);
    }

    pure pragma(inline, true)
    size_t activeWidth() const
        => m_vt.h.res;

    pure pragma(inline, true)
    size_t activeHeight() const
        => m_vt.v.res;

    pure pragma(inline, true)
    Color[][] allBuffers()
        => m_allBuffers;

    // dfmt off
    void fullClear()
    {
        m_bufferVBlankLine[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_bufferVBlankLine[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferVBlankLine[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;
        m_bufferVBlankLine[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLANK;

        m_bufferVSyncLine[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.CSYNC;
        m_bufferVSyncLine[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.BLANK;
        m_bufferVSyncLine[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.CSYNC;
        m_bufferVSyncLine[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.CSYNC;

        m_bufferHFrontSyncBack[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_bufferHFrontSyncBack[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferHFrontSyncBack[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;

        foreach (ref Color[] buf; m_lineBuffers)
            buf[] = Color.WHITE;
    }
    // dfmt on

    pure pragma(inline, true)
    inout(Color)[] getLine(uint y) inout
        => m_lineBuffers[y % ct_lineBufferCount];
}
