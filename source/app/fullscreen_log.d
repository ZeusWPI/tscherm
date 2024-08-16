module app.fullscreen_log;

import app.vga.color;
import app.vga.font : Font;
import app.vga.framebuffer : FrameBuffer;

import idfd.log : Logger;

import ministd.algorithm : swap;
import ministd.traits : isInstanceOf;

@safe:

struct FullscreenLog(uint ct_width, uint ct_height, FontT) //
if (isInstanceOf!(Font, FontT))
{
nothrow @nogc:
    private enum log = Logger!"FullscreenLog"();
    private enum ct_font = FontT();

    private uint m_currX;
    private uint m_currY;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize()
    {
    }

    void clear()
    {
    }

    void write(const(char)[] message)
    {
    }

    void writeln(const(char)[] message)
    {
    }

    void drawLine(Color[] buf, uint y)
    {
        enum const(char)[] text = "Hello";
        uint x = 0;
        if (0 <= y && y < ct_font.glyphHeight)
        {
            foreach (char c; text)
            {
                if (x >= ct_width)
                    break;
                buf[x .. x + ct_font.glyphWidth] = ct_font.getGlyphLine(c, y);
                x += ct_font.glyphWidth;
            }
        }
        buf[x .. ct_width] = Color.BLACK;

        for (size_t i = 0; i < ct_width; i += 4)
        {
            swap(buf[i + 0], buf[i + 3]);
            swap(buf[i + 1], buf[i + 2]);
            swap(buf[i + 0], buf[i + 1]);
            swap(buf[i + 2], buf[i + 3]);
        }
    }
}
