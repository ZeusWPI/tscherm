module app.pong.drawer;

import app.vga.color : Color;
import app.vga.font : Font;
import app.vga.framebuffer;

import idfd.log : Logger;

import ministd.math : clamp;

@safe nothrow @nogc:

// Used with 7-color grayscale
struct PongDrawer
{
nothrow @nogc:
    private enum log = Logger!"PongDrawer"();

    private FrameBuffer m_fb;
    private int m_barWidth;
    private int m_barHeight;
    private int m_barYMin;
    private int m_barYMax;
    private int m_barY;

scope:
    this(return scope FrameBuffer fb)
    in (fb !is null)
    {
        m_fb = fb;
        m_barWidth = 4;
        m_barHeight = (m_fb.activeHeight - 2) / 5;
        m_barYMin = 8;
        m_barYMax = m_fb.activeHeight - 8 - m_barHeight;

        reset;
    }

    void reset()
    {
        m_barY = (m_fb.activeHeight / 2) - (m_barHeight / 2);
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
        // TODO: Clear and draw only the changed parts
        foreach (y; m_barY .. m_barY + m_barHeight)
        {
            auto line = m_fb[y];
            line[0 .. m_barWidth] = Color.WHITE;
        }
    }

    void moveBar(short amount)
    {
        m_barY += amount;
        m_barY = m_barY.clamp(m_barYMin, m_barYMax);
    }
}
