module app.vga.color;

@safe nothrow @nogc:

struct Color
{
nothrow @nogc:
    ubyte m_value;

    // dfmt off
    enum Color BLACK   = Color(0);
    enum Color RED     = Color(1 << 0);
    enum Color GREEN   = Color(1 << 1);
    enum Color BLUE    = Color(1 << 2);
    enum Color YELLOW  = RED | GREEN;
    enum Color MAGENTA = RED | BLUE;
    enum Color CYAN    = GREEN | BLUE;
    enum Color WHITE   = RED | GREEN | BLUE;

    enum Color BLANK   = BLACK;
    enum Color HSYNC   = Color(1 << 6);
    enum Color VSYNC   = Color(1 << 7);
    enum Color CSYNC   = HSYNC | VSYNC;
    // dfmt on

    alias m_value this;

const scope:
    auto opBinary(string op)(const Color rhs)
    {
        return mixin("Color(m_value " ~ op ~ " rhs.m_value)");
    }
}
