module app.vga.framebuffer_interrupt.interrupt_drawer;

import app.vga.color : Color;
import app.vga.video_timings : VideoTimings;

import ministd.algorithm : swap;

@safe nothrow @nogc:

struct InterruptDrawer(VideoTimings ct_vt)
{
    bool reverse;

    void initialize()
    {
    }

    @trusted
    void drawLine(Color[] buf, uint y)
    {
        // uint i = (y + frame / 30) % 4;
        // if (i == 0)
        //     buf[] = Color.WHITE;
        // else
        //     buf[] = Color.BLACK;

        // disassemble memset: x /29i 0x4000c44c

        // (690) TScherm: line 10000: avgIdle=29.281100 avgDraw=2.209500
        // (1003) TScherm: line 20000: avgIdle=29.047900 avgDraw=2.204200
        // (1316) TScherm: line 30000: avgIdle=28.973700 avgDraw=2.202433
        // (1629) TScherm: line 40000: avgIdle=28.936075 avgDraw=2.201550
        buf[0 .. y] = Color.WHITE;
        buf[y .. $] = Color.BLACK;
        // Little endian to ... medium endian?
        uint wordStart = y & ~3;
        swap(buf[wordStart], buf[wordStart + 3]);
        swap(buf[wordStart + 1], buf[wordStart + 2]);
        swap(buf[wordStart], buf[wordStart + 1]);
        swap(buf[wordStart + 2], buf[wordStart + 3]);

        // (690) TScherm: line 10000: avgIdle=29.587200 avgDraw=1.902300
        // (1003) TScherm: line 20000: avgIdle=29.350650 avgDraw=1.900150
        // (1316) TScherm: line 30000: avgIdle=29.276500 avgDraw=1.899067
        // (1629) TScherm: line 40000: avgIdle=29.239725 avgDraw=1.898550
        // buf[] = Color.BLACK;
        // buf[y ^ 2] = Color.WHITE;

        // (815) TScherm: line 10000: avgIdle=4.712600 avgDraw=39.285600
        // (1252) TScherm: line 20000: avgIdle=4.410350 avgDraw=39.285200
        // (1688) TScherm: line 30000: avgIdle=4.307133 avgDraw=39.281367
        // (2124) TScherm: line 40000: avgIdle=4.255700 avgDraw=39.278100
        // buf[] = Color.BLACK;
        // foreach (x; 0 .. buf.length)
        //     if ((x + y) % 8 == 0)
        //         buf[x] = Color.WHITE;

        // buf[] = Color.BLACK;
        // foreach (x; 0 .. buf.length)
        //     if ((x + y) % 4 == 0)
        //         buf[x] = Color.WHITE;
        //     else
        //         buf[x] = Color.BLACK;
    }
}
