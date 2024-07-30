module app.fullscreen_log;

import app.vga.color;
import app.vga.font : Font;
import app.vga.framebuffer : FrameBuffer;

import idfd.log : Logger;

@safe:

struct FullscreenLog
{
nothrow @nogc:
    private enum log = Logger!"FullscreenLog"();

    private enum font = Font!"ignore"();
    private FrameBuffer m_fb;
    private ushort m_currX;
    private ushort m_currY;

scope:
    this(return scope FrameBuffer fb)
    in (fb !is null)
    {
        m_fb = fb;

        clear;
    }

    void put(const(char) c)
    {
        if (c == '\n')
        {
            m_currX = 0;
            m_currY += font.glyphHeight;
        }
        else
        {
            auto glyph = font[c];
            foreach (y; 0 .. font.glyphHeight)
                foreach (x; 0 .. font.glyphWidth)
                {
                    Color color = glyph[y][x] > 0x80 ? Color.WHITE : Color.BLACK;
                    m_fb[m_currY + y, m_currX + x] = color;
                }

            m_currX += font.glyphWidth;
            if (m_currX >= m_fb.activeWidth)
            {
                m_currX = 0;
                m_currY += font.glyphHeight;
            }
        }

        if (m_currY >= m_fb.activeHeight - font.glyphHeight)
            m_currY = 0;
    }

    void write(const(char)[] message)
    {
        log.info!"write: %.*s"(message.length, &message[0]);
        foreach (const c; message)
            put(c);
    }

    void writeln(const(char)[] message)
    {
        write(message);
        put('\n');
    }

    void clear()
    {
        m_fb.clear;
        m_currX = 0;
        m_currY = 0;
    }
}
