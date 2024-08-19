module app.text_view;

import app.vga.color;
import app.vga.font : Font;
import app.vga.framebuffer : FrameBuffer;

import idfd.log : Logger;

import ministd.algorithm : swap;
import ministd.traits : isInstanceOf;
import ministd.typecons : DynArray, UniqueHeapArray;

@safe nothrow @nogc:

struct TextView(uint ct_width, uint ct_height, FontT) //
if (isInstanceOf!(Font, FontT))
{
nothrow @nogc:
    private enum log = Logger!"FullscreenLog"();

    enum ct_font = FontT();
    enum ct_maxCharsPerRow = ct_width / ct_font.glyphWidth;
    enum ct_maxRows = ct_height / ct_font.glyphHeight;

    static assert(ct_maxCharsPerRow >= 1);
    static assert(ct_maxRows >= 1);

    private UniqueHeapArray!(DynArray!char) m_text;
    private size_t m_currRow;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize()
    {
        m_text = typeof(m_text).create(ct_maxRows);
    }

    void writeln(const(char)[] message = "")
    {
        if (message.length >= ct_maxCharsPerRow)
            message = message[0 .. ct_maxCharsPerRow];
        m_text[m_currRow].put(message);
        m_currRow++;
    }

    void clear()
    {
        foreach (row; m_text)
            row.reset;
        m_currRow = 0;
    }

    void drawLine(Color[] buf, uint y)
    in (y < ct_height)
    {
        uint row = y / ct_font.glyphHeight;

        if (row >= ct_maxRows || m_text[row].empty)
        {
            buf[] = Color.BLACK;
        }
        else
        {
            uint glyphY = y % ct_font.glyphHeight;

            const(char)[] text = m_text.get[row];

            uint xBegin, xEnd;
            foreach (char c; text)
            {
                xEnd = xBegin + ct_font.glyphWidth;
                buf[xBegin .. xEnd] = ct_font.getGlyphLine(c, glyphY);
                xBegin = xEnd;
            }
            buf[xEnd .. ct_width] = Color.BLACK;

            () @trusted {
                ushort[] usBuf = cast(ushort[]) buf;
                for (size_t i = 0; i < ct_width / 2; i += 2)
                    swap(usBuf[i], usBuf[i + 1]);
            }();
        }
    }
}
