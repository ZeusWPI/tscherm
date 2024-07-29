module app.pong.drawer;

import app.vga.color : Color;
import app.vga.font : Font;
import app.vga.framebuffer;

import idfd.log : Logger;

import ministd.traits : isInstanceOf;

@safe nothrow @nogc:

// Used with 7-color grayscale
struct PongDrawer
{
nothrow @nogc:
    private enum log = Logger!"PongDrawer"();

    private FrameBuffer m_fb;
    private uint m_barWidth;
    private uint m_barHeight;
    private uint m_barYMax;
    private uint m_barY;

scope:
    this(return scope FrameBuffer fb)
    in (fb !is null)
    {
        m_fb = fb;
        m_barWidth = 4;
        m_barHeight = (m_fb.activeHeight - 2) / 5;
        m_barYMax = m_fb.activeHeight - 1 - m_barHeight;
        m_barY = (m_fb.activeHeight - 2) / 2 + 1 - (m_barHeight / 2);

        m_fb.clear;
        drawBorders;
        drawBar;
    }

    void drawBorders()
    {
        m_fb[0][] = Color.WHITE;
        m_fb[$ - 1][] = Color.WHITE;
    }

    void clearBar()
    {
        foreach (y; m_barY .. m_barY + m_barHeight)
        {
            auto line = m_fb[y];
            line[0 .. m_barWidth] = Color.BLACK;
        }
    }

    void drawBar()
    {
        foreach (y; m_barY .. m_barY + m_barHeight)
        {
            auto line = m_fb[y];
            line[0 .. m_barWidth] = Color.WHITE;
        }
    }

    void moveBarDown(short amount)
    {
        m_barY += amount;
        if (m_barY >= m_barYMax)
            m_barY = m_barYMax;
    }

    void moveBarUp(short amount)
    {
        if (amount >= m_barY)
            m_barY = 0;
        else
            m_barY -= amount;
    }
}
