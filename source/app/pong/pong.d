module app.pong.pong;

import app.pong.input : PongInput, PongInputCheckResult;
import app.text_view : TextView;
import app.vga.color : Color;

import idfd.log : Logger;

import idf.esp_timer : esp_timer_get_time;

import ministd.math : abs, clamp, inRange;
import ministd.conv : to;

@safe:

struct Pong(uint ct_width, uint ct_height, int ct_pinUp, int ct_pinDown, FontT)
{
    enum log = Logger!"Pong"();

    private enum uint ct_tickPeriodUs = (10 ^^ 6) / 66;

    private enum Color ct_backgroundColor = Color.BLACK;
    private enum Color ct_borderColor = Color(Color.WHITE / 2);
    private enum Color ct_barColor = Color.WHITE;
    private enum Color ct_ballColor = Color(Color.WHITE / 4 * 3);

    private enum ushort ct_borderThickness = 2;

    private enum ushort ct_fieldWidth = ct_width;
    private enum ushort ct_fieldHeight = ct_height - ct_borderThickness * 2;
    private enum ushort ct_fieldX = 0;
    private enum ushort ct_fieldY = ct_borderThickness;

    private enum ushort ct_barWidth = (ct_fieldWidth / 40) & ~1;
    private enum ushort ct_barHeight = (ct_fieldHeight / 5) & ~1;
    private enum ushort ct_barX = 4;
    private enum ushort ct_barYMin = 0;
    private enum ushort ct_barYMax = ct_fieldHeight - ct_barYMin - ct_barHeight;
    private enum ushort ct_barMoveSpeed = 4;

    private enum ushort ct_ballRadius = 2; /// 0 for a single pixel
    private enum ushort ct_ballMoveSpeed = 5;

    private enum long ct_gameOverLengthUs = 3 * 10 ^^ 6;

    private const(FontT)* m_font;
    private TextView!(ct_fieldWidth, ct_fieldHeight, FontT) m_fieldTextView;

    private PongInput!(ct_pinUp, ct_pinDown) m_pongInput;

    private long m_lastTickTimeUs;

    private short m_barY;

    private short m_ballX;
    private short m_ballY;
    private short m_ballXVelocity;
    private short m_ballYVelocity;

    private uint m_score;
    private bool m_gameOver;
    private long m_gameOverTimeUs;

scope:
    void initialize(const(FontT)* font)
    {
        m_font = font;
        m_fieldTextView.initialize(font);

        m_pongInput.initialize;

        reset;
    }

    void reset()
    {
        long randSeed = (() @trusted => esp_timer_get_time())();

        m_lastTickTimeUs = 0;

        m_barY = (ct_fieldHeight - ct_barHeight) / 2;

        m_ballX = (ct_fieldWidth / 5) * 4;
        m_ballY = ct_fieldHeight / 2;
        m_ballXVelocity = -6;
        m_ballYVelocity = ((randSeed % 8) - 4);
        if (m_ballYVelocity <= 0)
            m_ballYVelocity -= 1;

        m_score = 0;
        m_gameOver = false;
        m_gameOverTimeUs = 0;
    }

    void tickIfReady()
    {
        long now = (() @trusted => esp_timer_get_time())();
        if (abs(now - m_lastTickTimeUs) >= ct_tickPeriodUs)
        {
            m_lastTickTimeUs = now;

            if (m_gameOver)
            {
                if (now - m_gameOverTimeUs >= ct_gameOverLengthUs)
                    reset;
                return;
            }

            PongInputCheckResult inputCheckResult = m_pongInput.check;
            if (inputCheckResult.up || inputCheckResult.down)
            {
                if (inputCheckResult.up)
                    m_barY -= ct_barMoveSpeed;
                else
                    m_barY += ct_barMoveSpeed;
                m_barY = m_barY.clamp!short(ct_barYMin, ct_barYMax);
            }

            m_ballX += m_ballXVelocity;
            m_ballY += m_ballYVelocity;
            if (!m_ballX.inRange(0, ct_fieldWidth))
            {
                m_ballX = m_ballX.clamp!short(0, ct_fieldWidth);
                m_ballXVelocity *= -1;
            }
            if (!m_ballY.inRange(0, ct_fieldHeight))
            {
                m_ballY = m_ballY.clamp!short(0, ct_fieldHeight);
                m_ballYVelocity *= -1;
            }

            if (m_ballX - ct_ballRadius < ct_barX + ct_barWidth)
            {
                if (m_ballY.inRange(m_barY, m_barY + ct_barHeight))
                {
                    m_ballXVelocity *= -1;
                    m_score++;
                }
                else
                {
                    m_gameOver = true;
                    m_gameOverTimeUs = now;

                    m_fieldTextView.clear;
                    foreach (i; 0 .. 6)
                        m_fieldTextView.writeln;
                    m_fieldTextView.writeln("                Game Over!");
                    m_fieldTextView.write("                 Score: ");
                    m_fieldTextView.writeln(m_score.to!(char[]));
                }
            }
        }
    }

    void drawLine(Color[] buf, const uint y) const
    {
        if (y.inRange(ct_fieldY, ct_fieldY + ct_fieldHeight))
        {
            drawFieldLine(buf[ct_fieldX .. ct_fieldX + ct_fieldWidth], y - ct_fieldY);
        }
        else
        {
            buf[] = ct_borderColor;
        }
    }

    private
    void drawFieldLine(Color[] buf, const uint y) const
    in (buf.length == ct_fieldWidth)
    in (y < ct_fieldHeight)
    {
        if (!m_gameOver)
        {
            buf[] = ct_backgroundColor;

            // Draw bar
            if (y.inRange(m_barY, m_barY + ct_barHeight))
            {
                static assert(ct_barX % 4 == 0, "Can't draw bar without xoring");
                static assert(ct_barWidth % 4 == 0, "Can't draw bar without xoring");

                buf[ct_barX .. ct_barX + ct_barWidth] = ct_barColor;
            }

            // Draw ball
            if (y.inRange!"[]"(m_ballY - ct_ballRadius, m_ballY + ct_ballRadius))
                foreach (x; m_ballX - ct_ballRadius .. m_ballX + ct_ballRadius + 1)
                    buf[x ^ 2] = ct_ballColor;
        }
        else
        {
            m_fieldTextView.drawLine(buf, y);
        }
    }
}
