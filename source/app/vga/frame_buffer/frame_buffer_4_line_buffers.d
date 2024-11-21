module app.vga.frame_buffer.frame_buffer_4_line_buffers;

import app.vga.color : Color;
import app.vga.frame_buffer.base : FrameBuffer;
import app.vga.video_timings : VideoTimings;

@safe nothrow @nogc:

final
class FrameBufferSimple4LineBuffers(VideoTimings ct_vt) : FrameBuffer!ct_vt
{
nothrow @nogc:
    enum log = Logger!"FrameBufferSimple4LineBuffers"();

    private Color[] m_lineBufferBlank;
    private Color[] m_lineBufferVSync;
    private Color[] m_lineBufferColor1;
    private Color[] m_lineBufferColor2;

scope:
    this()
    {
        m_lineBufferBlank = dallocArray!Color(ct_vt.h.total);
        m_lineBufferVSync = dallocArray!Color(ct_vt.h.total);
        m_lineBufferColor1 = dallocArray!Color(ct_vt.h.total);
        m_lineBufferColor2 = dallocArray!Color(ct_vt.h.total);

        m_allBuffers = dallocArray!(Color[])(ct_vt.v.total);
        foreach (y, ref Color[] lineBuffer; m_allBuffers)
        {
            if (ct_vt.v.resStart <= y && y < ct_vt.v.resEnd)
            {
                if (y % 2 == 0)
                    lineBuffer = m_lineBufferColor1;
                else
                    lineBuffer = m_lineBufferColor2;
            }
            else if (ct_vt.v.syncStart <= y && y <= ct_vt.v.syncEnd)
            {
                lineBuffer = m_lineBufferVSync;
            }
            else
            {
                lineBuffer = m_lineBufferBlank;
            }
        }

        m_activeLineBuffers = dallocArray!(Color[])(ct_vt.v.res);
        foreach (y, ref Color[] activeLineBuffer; m_activeLineBuffers)
            activeLineBuffer = m_allBuffers[vt.v.resStart + y][vt.h.resStart .. vt.h.resEnd];

        fullClear;
    }

    ~this()
    {
        dfree(m_activeLineBuffers);
        dfree(m_allBuffers);
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
        dfree(m_lineBufferColor1);
        dfree(m_lineBufferColor2);
    }

    pure
    void fill(Color color)
    {
        for (size_t y = 0; y < ct_vt.v.res; y++)
        {
            m_activeLineBuffers[y][] = color;
            if (y == 1)
                break;
        }
    }

    // dfmt off
    override
    void fullClear()
    {
        m_lineBufferBlank[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferBlank[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferBlank[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferBlank[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.BLANK;

        m_lineBufferVSync[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.CSYNC;
        m_lineBufferVSync[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.BLANK;
        m_lineBufferVSync[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.CSYNC;
        m_lineBufferVSync[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.CSYNC;

        m_lineBufferColor1[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferColor1[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferColor1[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferColor1[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.BLACK;

        m_lineBufferColor2[ct_vt.h.frontStart .. ct_vt.h.frontEnd] = Color.BLANK;
        m_lineBufferColor2[ct_vt.h.syncStart  .. ct_vt.h.syncEnd ] = Color.CSYNC;
        m_lineBufferColor2[ct_vt.h.backStart  .. ct_vt.h.backEnd ] = Color.BLANK;
        m_lineBufferColor2[ct_vt.h.resStart   .. ct_vt.h.resEnd  ] = Color.BLACK;
    }
    // dfmt on
}
