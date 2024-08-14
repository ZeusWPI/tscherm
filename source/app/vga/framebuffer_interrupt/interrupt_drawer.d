module app.vga.framebuffer_interrupt.interrupt_drawer;

import app.vga.color : Color;

import ministd.algorithm : swap;

@safe nothrow @nogc:

struct InterruptDrawer
{
    bool reverse;

    void initialize()
    {
    }

    void drawLine(Color[] buf, uint y, uint frame)
    {
        // uint i = (y + frame / 30) % 4;
        // if (i == 0)
        //     buf[] = Color.WHITE;
        // else
        //     buf[] = Color.BLACK;

        buf[0 .. y] = Color.WHITE;
        buf[y .. $] = Color.BLACK;

        if (y & 1)
        {
            swap(buf[y - 1], buf[y]);
        }
    }
}
