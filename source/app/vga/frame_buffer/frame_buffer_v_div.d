module app.vga.frame_buffer.frame_buffer_v_div;

import app.vga.color : Color;
import app.vga.frame_buffer.base : FrameBuffer;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import idfd.log : Logger;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:

final
class FrameBufferVDiv(VideoTimings ct_vt, int vDivide) : FrameBuffer!ct_vt
{
nothrow @nogc:
    enum log = Logger!"FrameBufferVDiv"();

    private Color[] m_bufferVBlankLine;
    private Color[] m_bufferVSyncLine;
    private Color[] m_bufferHFrontSyncBack;

scope:
    this()
    {
        assert(ct_vt.v.frontStart == 0); // Assume VideoTimings uses order: front, sync, back, res

        m_bufferVBlankLine = dallocArrayCaps!Color(ct_vt.h.total, MALLOC_CAP_DMA);
        m_bufferVSyncLine = dallocArrayCaps!Color(ct_vt.h.total, MALLOC_CAP_DMA);
        m_bufferHFrontSyncBack = dallocArrayCaps!Color(
            ct_vt.h.front + ct_vt.h.sync + ct_vt.h.back, MALLOC_CAP_DMA);

        m_activeLineBuffers = dallocArray!(Color[])(ct_vt.v.res);
        foreach (y, ref Color[] buf; m_activeLineBuffers)
        {
            size_t i = y % vDivide;
            if (i == 0)
                buf = dallocArrayCaps!Color(ct_vt.h.res, MALLOC_CAP_DMA);
            else
                buf = m_activeLineBuffers[y - i];
        }

        // Lines with an active part use 2 buffers, the buffer for the inactive part (m_bufferHFrontSyncBack) is reused
        m_allBuffers = dallocArray!(Color[])(ct_vt.v.total + ct_vt.v.res);
        foreach (i, ref Color[] buf; m_allBuffers)
        {
            if (ct_vt.v.syncStart <= i && i < ct_vt.v.syncEnd)
                buf = m_bufferVSyncLine;
            else if (i < ct_vt.v.backEnd)
                buf = m_bufferVBlankLine;
            else
            {
                size_t resBufferIndex = i - ct_vt.v.front - ct_vt.v.sync - ct_vt.v.back;
                if (resBufferIndex % 2 == 0)
                    buf = m_bufferHFrontSyncBack;
                else
                {
                    size_t y = resBufferIndex / 2;
                    buf = m_activeLineBuffers[y];
                }
            }
        }

        fullClear;
    }

    override
    void fill(Color color)
    {
        for (size_t y; y < m_activeLineBuffers.length; y += vDivide)
            m_activeLineBuffers[y][] = color;
    }

    // dfmt off
    override
    void fullClear()
    {
        m_bufferVBlankLine[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.BLANK;
        m_bufferVBlankLine[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.BLANK;
        m_bufferVBlankLine[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferVBlankLine[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.BLANK;

        m_bufferVSyncLine[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.CSYNC;
        m_bufferVSyncLine[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.CSYNC;
        m_bufferVSyncLine[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.BLANK;
        m_bufferVSyncLine[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.CSYNC;

        m_bufferHFrontSyncBack[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.BLANK;
        m_bufferHFrontSyncBack[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.CSYNC;
        m_bufferHFrontSyncBack[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.BLANK;

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
