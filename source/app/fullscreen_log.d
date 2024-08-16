module app.fullscreen_log;

import app.vga.color;
import app.vga.font : Font;
import app.vga.framebuffer : FrameBuffer;

import idfd.log : Logger;

import ministd.traits : isInstanceOf;

@safe:

struct FullscreenLog(size_t ct_width, size_t ct_height, FontT) //
if (isInstanceOf!(Font, FontT))
{
nothrow @nogc:
    private enum log = Logger!"FullscreenLog"();
    private enum ct_font = FontT();

    private ushort m_currX;
    private ushort m_currY;

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
}
