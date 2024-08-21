module app.pong.drawer;

import app.vga.color : Color;
import app.vga.font : Font;
import app.vga.framebuffer;

import idfd.log : Logger;

import ministd.math : clamp;

@safe nothrow @nogc:

struct PongDrawer(uint ct_width, uint ct_height)
{
nothrow @nogc:
    private enum log = Logger!"PongDrawer"();

    private enum Color ct_backgroundColor = Color.BLACK;
    private enum Color ct_borderColor = Color(Color.WHITE / 2);
    private enum Color ct_barColor = Color.WHITE;

    private enum uint ct_borderThickness = 2;

    private enum uint ct_fieldWidth = ct_width;
    private enum uint ct_fieldHeight = ct_height - ct_borderThickness * 2;
    private enum uint ct_fieldX = 0;
    private enum uint ct_fieldY = ct_borderThickness;

    private enum uint ct_barWidth = (ct_fieldWidth / 40) & ~1;
    private enum uint ct_barHeight = (ct_fieldHeight / 5) & ~1;
    private enum uint ct_barX = 4;
    private enum uint ct_barYMin = 8;
    private enum uint ct_barYMax = ct_fieldHeight - ct_barYMin - ct_barHeight;

    private uint m_barY = (ct_fieldHeight - ct_barHeight) / 2;

scope:
    void initialize()
    {
    }

    void moveBar(short inputSpeed)
    {
        m_barY += inputSpeed;
        m_barY = m_barY.clamp(ct_barYMin, ct_barYMax);
    }

    void drawLine(Color[] buf, const uint y)
    {
        if (ct_fieldY <= y && y < ct_fieldY + ct_fieldHeight) // In field
        {
            const uint yInField = y - ct_fieldY;
            Color[] bufField = buf;

            // Draw bar
            if (m_barY <= yInField && yInField < m_barY + ct_barHeight)
            {
                static assert(ct_barX % 4 == 0);
                static assert(ct_barWidth % 4 == 0);

                bufField[0 .. ct_barX] = ct_backgroundColor;
                bufField[ct_barX .. ct_barX + ct_barWidth] = ct_barColor;
                bufField[ct_barX + ct_barWidth .. ct_fieldWidth] = ct_backgroundColor;
            }
            else
            {
                bufField[] = ct_backgroundColor;
            }
        }
        else // Outside of field
        {
            buf[] = ct_borderColor;
        }
    }
}
