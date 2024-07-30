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
    enum log = Logger!"FrameBuffer"();

    protected Color[] m_lineBufferBlank;
    protected Color[] m_lineBufferVSync;

scope:
    this(in VideoTimings vt)
    {
        super(vt);

        m_lineBufferBlank = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_lineBufferVSync = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);

        foreach (y; 0 .. m_lineBuffers.length)
        {
            if (m_vt.v.resStart <= y && y < m_vt.v.resEnd)
            {
                size_t i = (y - m_vt.v.resStart) % vDivide;
                if (i == 0)
                    m_lineBuffers[y] = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
                else
                    m_lineBuffers[y] = m_lineBuffers[y - i];
            }
            else if (m_vt.v.syncStart <= y && y <= m_vt.v.syncEnd)
                m_lineBuffers[y] = m_lineBufferVSync;
            else
                m_lineBuffers[y] = m_lineBufferBlank;
        }

        fullClear;
    }

    // dfmt off
    void fullClear()
    {
        m_lineBufferBlank[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferBlank[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferBlank[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferBlank[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLANK;

        m_lineBufferVSync[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.CSYNC;
        m_lineBufferVSync[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.BLANK;
        m_lineBufferVSync[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.CSYNC;
        m_lineBufferVSync[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.CSYNC;

        for (size_t y = m_vt.v.resStart; y < m_vt.v.resEnd; y += vDivide)
        {
            Color[] line = m_lineBuffers[y][0 .. m_vt.h.total];
            line[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
            line[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
            line[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;
            line[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLACK;
        }
    }
    // dfmt on

    ~this()
    {
        for (size_t y = m_vt.v.resStart; y < m_vt.v.resEnd; y += vDivide)
            dfree(m_lineBuffers[y]);
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
    }
}
