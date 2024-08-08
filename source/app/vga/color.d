module app.vga.color;

@safe nothrow @nogc:

struct Color
{
nothrow @nogc:
    ubyte m_value;

    // dfmt off
    enum Color BLACK = Color(0);
    enum Color WHITE = Color(0x7f);

    enum Color BLANK = BLACK;
    enum Color CSYNC = Color(1 << 7);
    // dfmt on

    alias m_value this;

const scope:
    auto opBinary(string op)(const Color rhs)
    {
        return mixin("Color(m_value " ~ op ~ " rhs.m_value)");
    }
}
