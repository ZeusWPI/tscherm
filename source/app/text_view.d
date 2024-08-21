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

    enum ct_maxCharsPerRow = ct_width / m_font.ct_glyphWidth;
    enum ct_maxRows = ct_height / m_font.ct_glyphHeight;

    static assert(ct_maxCharsPerRow >= 1);
    static assert(ct_maxRows >= 1);

    private const(FontT)* m_font;
    private UniqueHeapArray!(DynArray!char) m_text;
    private size_t m_currRow;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize(const(FontT)* font)
    {
        m_font = font;
        m_text = typeof(m_text).create(ct_maxRows);
    }

    void write(const(char)[] message = "")
    {
        for (size_t i; i < message.length; i++)
        {
            if (message[i] == '\n')
            {
                writeRaw(message[0 .. i]);
                message = message[i + 1 .. $];
                i = 0;
                m_currRow++;
            }
        }
        writeRaw(message);
    }

    void writeln(const(char)[] message = "")
    {
        write(message);
        write("\n");
    }

    private
    void writeRaw(const(char)[] message)
    {
        if (!message.length)
            return;
        while (true)
        {
            if (m_currRow == ct_maxRows)
            {
                // Todo: autoscroll
                return;
            }
            size_t currLength = m_text[m_currRow].length;
            size_t combinedLength = currLength + message.length;
            if (combinedLength > ct_maxCharsPerRow)
            {
                ptrdiff_t remainingSpace = ct_maxCharsPerRow - currLength;
                m_text[m_currRow].put(message[0 .. remainingSpace]);
                message = message[remainingSpace .. $];
                m_currRow++;
            }
            else
            {
                m_text[m_currRow].put(message);
                return;
            }
        }
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
        uint row = y / m_font.ct_glyphHeight;

        if (row >= ct_maxRows || m_text[row].empty)
        {
            buf[] = Color.BLACK;
        }
        else
        {
            uint glyphY = y % m_font.ct_glyphHeight;

            const(char)[] text = m_text.get[row];

            uint xBegin, xEnd;
            foreach (char c; text)
            {
                xEnd = xBegin + m_font.ct_glyphWidth;
                buf[xBegin .. xEnd] = m_font.getGlyphLine(c, glyphY);
                xBegin = xEnd;
            }
            buf[xEnd .. ct_width] = Color.BLACK;
        }
    }
}
