module app.vga.framebuffer_simple;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

@safe nothrow @nogc:
// dfmt off

struct FrameBufferSimple3LineBuffers
{
nothrow @nogc:
    private const VideoTimings m_vt;
    private Color[][] m_lineBuffers;
    private Color[] m_lineBufferBlank;
    private Color[] m_lineBufferVSync;
    private Color[] m_lineBufferColor1;
    private Color[] m_lineBufferColor2;

    this(in VideoTimings vt)
    {
        m_vt = vt;
        m_lineBuffers = dallocArray!(Color[])(m_vt.v.total);
        m_lineBufferColor1 = dallocArray!Color(m_vt.h.total);
        m_lineBufferColor2 = dallocArray!Color(m_vt.h.total);
        m_lineBufferBlank  = dallocArray!Color(m_vt.h.total);
        m_lineBufferVSync  = dallocArray!Color(m_vt.h.total);

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

    ~this()
    {
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
        dfree(m_lineBufferColor1);
        dfree(m_lineBufferColor2);
        dfree(m_lineBuffers);
    }

    uint activeWidth() const pure => m_vt.h.res;
    uint activeHeight() const pure => m_vt.v.res;

    pure
    Color[][] linesWithSync()
    {
        return m_lineBuffers;
    }

    pure
    Color[] getLineWithSync(in uint y)
    in (y < m_vt.v.total)
    {
        return m_lineBuffers[m_vt.v.resStart + y][0 .. m_vt.h.total];
    }

    pure
    Color[] getLine(in uint y)
    in (y < m_vt.v.res)
    {
        return m_lineBuffers[m_vt.v.resStart + y][m_vt.h.resStart .. m_vt.h.resEnd];
    }

    pure
    Color[] opIndex(in uint y)
    in (y < m_vt.v.res)
    {
        return getLine(y);
    }

    pure
    ref Color opIndex(in uint y, in uint x)
    in (y < m_vt.v.res)
    in (x < m_vt.h.res)
    {
        return getLine(y)[x ^ 2];
    }

    pure
    void fill(Color color)
    {
        foreach (y; 0 .. 2)
            getLine(y)[] = color;
    }

    pure
    void clear() => fill(Color.BLACK);

    void fillIteratingColorsDiagonal(string indexFunc = "x/8+y")()
    {
        immutable Color[] colors = [
            Color.BLACK, Color.WHITE,
        ];

        foreach (y; 0 .. 2)
            foreach (x; 0 .. m_vt.h.res)
            {
                auto index = mixin(indexFunc);
                this[y, x] = colors[index % colors.length];
            }
    }
}

struct FrameBufferHalfLines
{
nothrow @nogc:
    private const VideoTimings m_vt;
    private Color[][] m_lineBuffers;
    private Color[] m_lineBufferBlank;
    private Color[] m_lineBufferVSync;
    private Color[] m_lineBufferColor1;
    private Color[] m_lineBufferColor2;

    this(in VideoTimings vt)
    {
        m_vt = vt;
        m_lineBuffers = dallocArray!(Color[])(m_vt.v.total);
        m_lineBufferColor1 = dallocArray!Color(m_vt.h.total);
        m_lineBufferColor2 = dallocArray!Color(m_vt.h.total);
        m_lineBufferBlank  = dallocArray!Color(m_vt.h.total);
        m_lineBufferVSync  = dallocArray!Color(m_vt.h.total);

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

    ~this()
    {
        dfree(m_lineBufferBlank);
        dfree(m_lineBufferVSync);
        dfree(m_lineBufferColor1);
        dfree(m_lineBufferColor2);
        dfree(m_lineBuffers);
    }

    pure
    uint activeWidth() const => m_vt.h.res;

    pure
    uint activeHeight() const => m_vt.v.res;

    pure
    Color[][] linesWithSync()
    {
        return m_lineBuffers;
    }

    pure
    Color[] getLineWithSync(in uint y)
    in (y < m_vt.v.total)
    {
        return m_lineBuffers[m_vt.v.resStart + y][0 .. m_vt.h.total];
    }

    pure
    Color[] getLine(in uint y)
    in (y < m_vt.v.res)
    {
        return m_lineBuffers[m_vt.v.resStart + y][m_vt.h.resStart .. m_vt.h.resEnd];
    }

    pure
    Color[] opIndex(in uint y)
    in (y < m_vt.v.res)
    {
        return getLine(y);
    }

    pure
    ref Color opIndex(in uint y, in uint x)
    in (y < m_vt.v.res)
    in (x < m_vt.h.res)
    {
        return getLine(y)[x ^ 2];
    }

    pure
    void fill(Color color)
    {
        foreach (y; 0 .. 2)
            getLine(y)[] = color;
    }

    pure
    void clear() => fill(Color.BLACK);

    void fillIteratingColorsDiagonal(string indexFunc = "x/8+y")()
    {
        immutable Color[] colors = [
            Color.BLACK, Color.WHITE,
        ];

        foreach (y; 0 .. 2)
            foreach (x; 0 .. m_vt.h.res)
            {
                auto index = mixin(indexFunc);
                this[y, x] = colors[index % colors.length];
            }
    }
}
