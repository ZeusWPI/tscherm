module app.vga.framebuffer;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import idf.heap.caps : MALLOC_CAP_DMA;

import ministd.heap_caps : dallocArrayCaps;

// dfmt off
@safe nothrow @nogc:

struct FrameBuffer
{
    private const VideoTimings m_vt;
    private Color[] m_lineBufferBlank;
    private Color[] m_lineBufferVSync;
    private Color[][] m_lineBuffers;

    int vDivide = 4;

    this(in VideoTimings vt)
    {
        m_vt = vt;
        m_lineBufferBlank = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);
        m_lineBufferVSync = dallocArrayCaps!Color(m_vt.h.total, MALLOC_CAP_DMA);

        m_lineBuffers = dallocArray!(Color[])(m_vt.v.total);

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

    ~this()
    {
        for (size_t y = m_vt.v.resStart; y < m_vt.v.resEnd; y += vDivide)
            dfree(m_lineBuffers[y]);
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
        dfree(m_lineBuffers);
    }

    size_t activeWidth() const pure => m_vt.h.res;
    size_t activeHeight() const pure => m_vt.v.res;

    Color[][] linesWithSync() pure
    {
        return m_lineBuffers;
    }

    Color[] getLineWithSync(in size_t y) pure
    in (y < m_vt.v.total)
    {
        return m_lineBuffers[m_vt.v.resStart + y][0 .. m_vt.h.total];
    }

    Color[] getLine(in size_t y) pure
    in (y < m_vt.v.res)
    {
        return m_lineBuffers[m_vt.v.resStart + y][m_vt.h.resStart .. m_vt.h.resEnd];
    }

    Color[] opIndex(in size_t y) pure
    in (y < m_vt.v.res)
    {
        return getLine(y);
    }

    ref Color opIndex(in size_t y, in size_t x) pure
    in (y < m_vt.v.res)
    in (x < m_vt.h.res)
    {
        return getLine(y)[x ^ 2];
    }

    void fill(Color color) pure
    {
        for (size_t y = 0; y < m_vt.v.res; y += vDivide)
            getLine(y)[] = color;
    }

    void clear() pure => fill(Color.BLACK);

    void fillIteratingColorsDiagonal(string indexFunc = "x+y/vDivide")()
    {
        immutable Color[] colors = [
            Color.WHITE, Color.BLACK,
        ];

        for (size_t y = 0; y < m_vt.v.res; y += vDivide)
            foreach (x; 0 .. m_vt.h.res)
            {
                auto index = mixin(indexFunc);
                this[y, x] = colors[index % colors.length];
            }
    }

    void drawGrayscaleImage(
        in ubyte[] image,
        in Color whiteColor = Color.WHITE,
        in Color blackColor = Color.BLACK,
    )
    in(image.length == m_vt.v.res * m_vt.h.res)
    {
        for (size_t y = 0; y < m_vt.v.res; y += vDivide)
            foreach (x; 0 .. m_vt.h.res)
            {
                ubyte imageByte = image[m_vt.h.res * y + x];
                this[y, x] = imageByte > 0x40 ? whiteColor : blackColor;
            }
    }
}
