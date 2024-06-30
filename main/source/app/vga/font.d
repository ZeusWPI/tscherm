module app.vga.font;

import ministd.traits : isSomeChar, Unqual;

@safe nothrow @nogc:

struct Font(string ignore)
{
    enum imagePath = "fonts/mc_16x32.bin";
    enum uint glyphCount = 95;
    enum uint glyphWidth = 16;
    enum uint glyphHeight = 32;
    enum uint imageLength = glyphWidth * glyphHeight * glyphCount;
    alias ImageType = ubyte[glyphWidth * glyphCount][glyphHeight];
    alias GlyphType = ubyte[glyphWidth][glyphHeight];
    enum ImageType image = cast(ImageType) import(imagePath)[0 .. imageLength];

pure const:

    GlyphType opIndex(C)(C c)
    if (isSomeChar!C)
    {
        if (c < ' ' || '~' < c)
            return this['?'];
        size_t index = c - ' ';
        return this[index];
    }

    GlyphType opIndex(I)(I i)
    if (!isSomeChar!I)
    in (i < glyphCount)
    {
        const uint imageXBegin = i * glyphWidth;
        const uint imageXEnd = imageXBegin + glyphWidth;

        GlyphType ret;
        foreach (const y; 0 .. glyphHeight)
            ret[y] = image[y][imageXBegin .. imageXEnd];
        return ret;
    }
}