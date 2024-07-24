module app.vga.framebuffer.simple_4_line_buffers;

import app.vga.color : Color;
import app.vga.framebuffer.base : FrameBuffer;
import app.vga.video_timings : VideoTimings;

@safe nothrow @nogc:

final
class FrameBufferSimple4LineBuffers : FrameBuffer
{
nothrow @nogc:
    private Color[] m_lineBufferBlank;
    private Color[] m_lineBufferVSync;
    private Color[] m_lineBufferColor1;
    private Color[] m_lineBufferColor2;

scope:
    this(in VideoTimings vt)
    {
        super(vt);

        m_lineBufferColor1 = dallocArray!Color(m_vt.h.total);
        m_lineBufferColor2 = dallocArray!Color(m_vt.h.total);
        m_lineBufferBlank = dallocArray!Color(m_vt.h.total);
        m_lineBufferVSync = dallocArray!Color(m_vt.h.total);

        foreach (y, ref Color[] lineBuffer; m_lineBuffers)
        {
            if (m_vt.v.resStart <= y && y < m_vt.v.resEnd)
            {
                if (y % 2 == 0)
                    lineBuffer = m_lineBufferColor1;
                else
                    lineBuffer = m_lineBufferColor2;
            }
            else if (m_vt.v.syncStart <= y && y <= m_vt.v.syncEnd)
            {
                lineBuffer = m_lineBufferVSync;
            }
            else
            {
                lineBuffer = m_lineBufferBlank;
            }
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

        m_lineBufferColor1[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferColor1[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferColor1[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferColor1[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLACK;

        m_lineBufferColor2[m_vt.h.frontStart .. m_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferColor2[m_vt.h.syncStart  .. m_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferColor2[m_vt.h.backStart  .. m_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferColor2[m_vt.h.resStart   .. m_vt.h.resEnd  ] = Color.BLACK;
    }
    // dfmt on

    ~this()
    {
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
        dfree(m_lineBufferColor1);
        dfree(m_lineBufferColor2);
    }
}
