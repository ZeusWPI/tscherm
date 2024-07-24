module app.vga.draw;

import app.vga.color : Color;
import app.vga.font : Font;
import app.vga.framebuffer;

import idfd.log : Logger;

import ministd.traits : isInstanceOf;

@safe nothrow @nogc:

struct Box
{
pure nothrow @nogc:
    size_t x1, x2, y1, y2;

const scope:
    bool valid() => x1 < x2 && y1 < y2;

    size_t width() => x2 - x1;
    size_t height() => y2 - y1;
}

struct Drawer
{
nothrow @nogc:
    private enum log = Logger!"Drawer"();

    private FrameBuffer m_fb;
    private Color m_backgroundColor;
    private size_t m_separatorX;
    private Color m_separatorColor;
    private Color m_textColor;

scope:
    this(return scope FrameBuffer fb)
    in (fb !is null)
    {
        m_fb = fb;

        m_backgroundColor = Color.BLACK;
        m_textColor = Color.GREEN;
        m_separatorX = m_fb.activeWidth * 7 / 10;
        m_separatorColor = Color.GREEN;

        drawLayout;
    }

    // dfmt off
    void appendText(char[] text)
    {
        enum font = Font!"ignore"();

        scrollBoxDown(
            Box(0, m_separatorX, 0, m_fb.activeHeight),
            font.glyphHeight, m_backgroundColor,
        );

        drawTextBox!(typeof(font), font)(
            Box(
                0, font.glyphWidth * text.length,
                m_fb.activeHeight - font.glyphHeight, m_fb.activeHeight,
            ),
            text,
        );
    }
    // dfmt on

    private
    void drawLayout()
    in (m_separatorX < m_fb.activeWidth)
    {
        foreach (y; 0 .. m_fb.activeHeight)
            m_fb[y, m_separatorX] = m_separatorColor;
    }

    private
    void scrollBoxDown(
        in Box box,
        size_t amount, const Color background,
    )
    in (box.valid)
    in (box.x2 <= m_fb.activeWidth)
    in (box.y2 <= m_fb.activeHeight)
    {
        if (amount == 0)
            return;
        if (amount > box.height)
            amount = box.height;

        foreach (y; box.y1 .. box.y2)
            foreach (x; box.x1 .. box.x2)
            {
                if (y + amount < box.y2)
                    m_fb[y, x] = m_fb[y + amount, x];
                else
                    m_fb[y, x] = background;
            }
    }

    private
    void drawTextBox(F, F font)(in Box box, const char[] text) //
    if (isInstanceOf!(Font, F))
    in (box.valid)
    in (box.x2 <= m_fb.activeWidth)
    in (box.y2 <= m_fb.activeHeight)
    in (box.width == text.length * font.glyphWidth)
    in (box.height == font.glyphHeight)
    {
        foreach (i, const c; text)
        {
            auto glyph = font[c];
            size_t xOffset = i * font.glyphWidth;
            foreach (y; 0 .. font.glyphHeight)
                foreach (x; 0 .. font.glyphWidth)
                {
                    Color color = glyph[y][x] > 0x80 ? m_textColor : m_backgroundColor;
                    m_fb[box.y1 + y, box.x1 + xOffset + x] = color;
                }
        }
    }
}
