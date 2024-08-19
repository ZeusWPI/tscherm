module app.vga.framebuffer_interrupt.interrupt_drawer;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import ministd.algorithm : swap;

@safe nothrow @nogc:

struct InterruptDrawer(VideoTimings ct_vt)
{
    void drawLine(Color[] buf, uint y)
    {
        Color nextColor = Color.WHITE;
        foreach (ref Color pixel; buf[0 .. y])
        {
            pixel = nextColor;
            if (nextColor == Color.BLACK)
                nextColor = Color.WHITE;
            else
                nextColor--;
        }

        buf[y .. $] = Color.BLACK;

        uint wordStart = y & ~3;
        swap(buf[wordStart], buf[wordStart + 2]);
        swap(buf[wordStart + 1], buf[wordStart + 3]);
    }
}
