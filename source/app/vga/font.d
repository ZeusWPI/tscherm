module app.vga.font;

import app.vga.color : Color;

import ldc.attributes : section;

import ministd.traits : isSomeChar;
import ministd.typecons : UniqueHeapArray;

@safe nothrow @nogc:

alias FontMC16x32 = Font!("fonts/mc_16x32.bin", 95, 16, 32);

struct Font(string ct_imagePath, size_t ct_glyphCount, size_t ct_glyphWidth_, size_t ct_glyphHeight_)
{
nothrow @nogc:
    enum uint ct_glyphWidth = ct_glyphWidth_;
    enum uint ct_glyphHeight = ct_glyphHeight_;

    private enum uint ct_imageLength = ct_glyphWidth * ct_glyphHeight * ct_glyphCount;
    private static immutable(Color[]) ct_image = readImage!ct_imagePath;
    static assert(ct_image.length == ct_imageLength);

    private UniqueHeapArray!Color m_image;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize()
    in (m_image.empty)
    {
        m_image = m_image.create(ct_image.length);
        m_image[] = ct_image[];
    }

const pragma(inline, true):
    const(Color)[] getGlyphLine(C)(C c, uint y) //
    if (isSomeChar!C)
    {
        if (' ' <= c && c <= '~')
        {
            size_t index = c - ' ';
            return getGlyphLine(index, y);
        }
        else
        {
            return getGlyphLine('?', y);
        }
    }

    const(Color)[] getGlyphLine(I)(I i, uint y) //
    if (!isSomeChar!I)
    in (i < ct_glyphCount)
    in (!m_image.empty)
    {
        const size_t begin = y * ct_glyphWidth * ct_glyphCount + i * ct_glyphWidth;
        const size_t end = begin + ct_glyphWidth;

        return m_image[begin .. end];
    }
}

private enum immutable(Color[]) readImage(string importPath) = () {
    if (__ctfe)
    {
        enum string str = import(importPath);
        Color[] image = new Color[str.length];

        static assert(str.length % 4 == 0);
        foreach (size_t i; 0 .. str.length)
            image[i ^ 2] = cast(Color) str[i];

        return image;
    }
    else
    {
        assert(false);
    }
}();
