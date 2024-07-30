module app.vga.font;

import ministd.traits : isSomeChar, Unqual;

@safe nothrow @nogc:

struct Font(string ignore)
{
pure nothrow @nogc:
    enum imagePath = "fonts/mc_16x32.bin";
    enum uint glyphCount = 95;
    enum uint glyphWidth = 16;
    enum uint glyphHeight = 32;
    enum uint imageLength = glyphWidth * glyphHeight * glyphCount;
    alias Image = ubyte[glyphWidth * glyphCount][glyphHeight];
    alias Glyph = ubyte[glyphWidth][glyphHeight];
    enum Image image = cast(Image) import(imagePath)[0 .. imageLength];

const scope:
    Glyph opIndex(C)(C c) //
    if (isSomeChar!C)
    {
        if (c < ' ' || '~' < c)
            return this['?'];
        size_t index = c - ' ';
        return this[index];
    }

    Glyph opIndex(I)(I i) //
    if (!isSomeChar!I)
    in (i < glyphCount)
    {
        const size_t imageXBegin = i * glyphWidth;
        const size_t imageXEnd = imageXBegin + glyphWidth;

        Glyph ret;
        foreach (const y; 0 .. glyphHeight)
            ret[y] = image[y][imageXBegin .. imageXEnd];
        return ret;
    }
}
