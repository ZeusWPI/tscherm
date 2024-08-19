module app.vga.font;

import app.vga.color : Color;

import ldc.attributes : section;

import ministd.traits : isSomeChar, Unqual;

@safe nothrow @nogc:

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
        return [];
    }
}();

struct Font()
{
nothrow @nogc:
    enum imagePath = "fonts/mc_16x32.bin";
    enum uint glyphCount = 95;
    enum uint glyphWidth = 16;
    enum uint glyphHeight = 32;
    enum uint imageLength = glyphWidth * glyphHeight * glyphCount;

    @section(".iram1")
    static immutable(Color[]) image = readImage!imagePath;
    static assert(image.length == imageLength);

const scope pragma(inline, true):
    immutable(Color)[] getGlyphLine(C)(C c, uint y) //
    if (isSomeChar!C)
    {
        if (c < ' ' || '~' < c)
            return getGlyphLine('?', y);
        size_t index = c - ' ';
        return getGlyphLine(index, y);
    }

    immutable(Color)[] getGlyphLine(I)(I i, uint y) //
    if (!isSomeChar!I)
    in (i < glyphCount)
    {
        const size_t begin = y * glyphWidth * glyphCount + i * glyphWidth;
        const size_t end = begin + glyphWidth;

        return image[begin .. end];
    }
}
