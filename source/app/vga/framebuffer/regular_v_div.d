module app.vga.framebuffer.regular_v_div;

import app.vga.color : Color;
import app.vga.framebuffer.base : FrameBuffer;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import idfd.log : Logger;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:

final
class FrameBufferRegularVDiv(int vDivide) : FrameBuffer
{
nothrow @nogc:
    enum log = Logger!"FrameBufferRegularVDiv"();

    protected Color[] m_bufferVBlankLine;
    protected Color[] m_bufferVSyncLine;
    protected Color[] m_bufferHFrontSyncBack;

scope:
    this(in VideoTimings vt)
    {
        super(vt);

        assert(m_vt.v.frontStart == 0); // Assume VideoTimings uses order: front, sync, back, res

        m_bufferVBlankLine = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_bufferVSyncLine = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_bufferHFrontSyncBack = dallocArrayCaps!Color(
            m_vt.h.front + m_vt.h.sync + m_vt.h.back, MALLOC_CAP_DMA);

        m_activeLineBuffers = dallocArray!(Color[])(m_vt.v.res);
        foreach (y, ref Color[] buf; m_activeLineBuffers)
        {
            size_t i = y % vDivide;
            if (i == 0)
                buf = dallocArrayCaps!Color(m_vt.h.res, MALLOC_CAP_DMA);
            else
                buf = m_activeLineBuffers[y - i];
        }

        // Lines with an active part use 2 buffers, the buffer for the inactive part (m_bufferHFrontSyncBack) is reused
        m_allBuffers = dallocArray!(Color[])(m_vt.v.res * 2 + m_vt.v.front + m_vt.v.sync + m_vt
                .v.back);
        foreach (i, ref Color[] buf; m_allBuffers)
        {
            if (m_vt.v.syncStart <= i && i < m_vt.v.syncEnd)
                buf = m_bufferVSyncLine;
            else if (i < m_vt.v.backEnd)
                buf = m_bufferVBlankLine;
            else
            {
                size_t resBufferIndex = i - m_vt.v.back - m_vt.v.sync - m_vt.v.front;
                if (resBufferIndex % 2 == 0)
                {
                    buf = m_bufferHFrontSyncBack;
                }
                else
                {
                    size_t y = resBufferIndex / 2;
                    buf = m_activeLineBuffers[y];
                }
            }
        }

        fullClear;
    }

    // dfmt off
    override
    void fullClear()
    {
        m_bufferVBlankLine[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLANK;
        m_bufferVBlankLine[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_bufferVBlankLine[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferVBlankLine[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;

        m_bufferVSyncLine[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.CSYNC;
        m_bufferVSyncLine[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.CSYNC;
        m_bufferVSyncLine[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.BLANK;
        m_bufferVSyncLine[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.CSYNC;

        m_bufferHFrontSyncBack[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_bufferHFrontSyncBack[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferHFrontSyncBack[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;

        for (size_t y; y < m_activeLineBuffers.length; y += vDivide)
            m_activeLineBuffers[y][] = Color.BLACK;
    }
    // dfmt on

    ~this()
    {
        dfree(m_allBuffers);
        dfree(m_bufferVBlankLine);
        dfree(m_bufferVSyncLine);
        dfree(m_bufferHFrontSyncBack);
        for (size_t y; y < m_activeLineBuffers.length; y += vDivide)
            dfree(m_activeLineBuffers[y]);
        dfree(m_activeLineBuffers);
    }
}
