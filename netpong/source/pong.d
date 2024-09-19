// Test with ping 192.168.1.1 -s 12 -p 4e4554504f4e472100EEFFC0 -c1
// dfmt off
module pong;

import net : Net, NetException;

import core.stdc.signal : SIGINT, signal;
import core.stdc.stdlib : atexit, exit;
import core.thread : Thread;
import core.time : Duration, seconds;

import std.algorithm : clamp, max, min;
import std.concurrency;
import std.format : f = format;
import std.math : abs;
import std.random;
import std.stdio : stderr, stdout, write, writef, writefln, writeln;
import std.string : fromStringz, toStringz;
import std.typecons : Nullable;

import importc.sdl : SDL_INIT_VIDEO, SDL_DOUBLEBUF, SDL_HWSURFACE, SDL_FULLSCREEN, SDL_RESIZABLE,
    SDL_KEYDOWN, SDL_KEYUP, SDL_PRESSED, SDL_QUIT, SDL_RELEASED,
    SDLK_DOWN, SDLK_ESCAPE, SDLK_s, SDLK_UP,
    SDL_Event, SDL_Rect, SDL_Surface,
    SDL_FillRect, SDL_GetError, SDL_GetKeyState, SDL_GetTicks, SDL_Init, SDL_MapRGB,
    SDL_PollEvent, SDL_Quit, SDL_SetVideoMode, SDL_UpdateRects, SDL_WM_SetCaption;

private @safe:

bool inRange(T1, T2, T3)(T1 val, T2 lower, T3 upper) => lower <= val && val < upper;

public
struct Pong
{
private:
    enum uint ct_fps = 75;

    enum ushort ct_width = 1024;
    enum ushort ct_height = 768;

    enum uint ct_backgroundColor = 0x000000U;
    enum uint ct_borderColor = 0x808080U;
    enum uint ct_paddleColor = 0xFFFFFFU;
    enum uint ct_ballColor = 0xC0C0C0U;

    enum ushort ct_fieldWidth = ct_width;
    enum ushort ct_fieldHeight = ct_height;

    enum ushort ct_paddleWidth = ct_fieldWidth / 40;
    enum ushort ct_paddleHeight = ct_fieldHeight / 5;
    enum short ct_paddleXPos = ct_fieldWidth - ct_paddleWidth;
    enum short ct_paddleSpeed = ct_height * 60 / (120 * ct_fps);

    enum ushort ct_ballRadius = ct_fieldHeight / 240; // 0 For a single pixel;
    enum ushort ct_ballWidth = 1 + 2 * ct_ballRadius;
    enum ushort ct_ballHeight = ct_ballWidth;
    enum short ct_ballSpeed = ct_width * 60 / (128 * ct_fps);

    enum NetMessageTypes : ubyte
    {
        PASS,
        LOST,
        RESET,
    }

    string m_networkInterface;
    string m_localAddress;
    string m_remoteAddress;

    SDL_Surface* m_screen;
    SDL_Rect m_oldPaddleRect, m_oldBallRect, m_paddleRect, m_ballRect; // Don't change field order
    int m_paddleYVelocity, m_ballXVelocity, m_ballYVelocity;
    bool m_hasBall;
    Tid m_netThread;
    uint m_lastFrameTick;
    bool m_roundOver, m_quit;

    public @trusted
    this(string networkInterface, string localAddress, string remoteAddress)
    {
        m_networkInterface = networkInterface;
        m_localAddress = localAddress;
        m_remoteAddress = remoteAddress;

        if (SDL_Init(SDL_INIT_VIDEO) < 0)
        {
            stderr.writefln!"Unable to init SDL: %s"(SDL_GetError);
            exit(1);
        }
        atexit(&SDL_Quit);

        m_screen = SDL_SetVideoMode(
            ct_width, ct_height, 16,
            SDL_DOUBLEBUF | SDL_HWSURFACE | SDL_RESIZABLE | SDL_FULLSCREEN,
        );
        if (m_screen is null)
        {
            stderr.writefln!"Unable to set video mode: %s"(SDL_GetError);
            exit(1);
        }

        SDL_WM_SetCaption("NETPONG", null);

        m_paddleRect.w = ct_paddleWidth;
        m_paddleRect.h = ct_paddleHeight;

        m_ballRect.w = ct_ballWidth;
        m_ballRect.h = ct_ballHeight;

        m_oldPaddleRect = m_paddleRect;
        m_oldBallRect = m_ballRect;

        m_netThread = spawnLinked(&netThreadEntrypoint, m_networkInterface, m_localAddress, m_remoteAddress);
    }

    public @trusted
    void run()
    {
    restartLoop:
        while (!m_quit)
        {
            reset;
        gameLoop:
            while (!m_roundOver)
            {
                do
                {
                    pollEvent;
                    if (m_quit)
                        break restartLoop;
                    if (m_roundOver)
                        break gameLoop;
                } while (SDL_GetTicks - m_lastFrameTick < 1000 / ct_fps);
                m_lastFrameTick = SDL_GetTicks;

                tick;
                if (m_roundOver)
                    break gameLoop;
                draw;
            }
        }
        exit(0);
    }

    @trusted
    void reset()
    {
        SDL_FillRect(m_screen, null, fromRGB(ct_backgroundColor));
        SDL_UpdateRects(m_screen, 4, &m_oldPaddleRect);

        m_paddleRect.x = ct_fieldWidth - 1 - ct_paddleWidth;
        m_paddleRect.y = (ct_fieldHeight - ct_paddleHeight) / 2;

        m_ballRect.x = (ct_fieldWidth - ct_ballWidth) / 2;
        m_ballRect.y = (ct_fieldHeight - ct_ballHeight) / 2;

        m_oldPaddleRect = m_paddleRect;
        m_oldBallRect = m_ballRect;

        m_ballXVelocity = ct_ballSpeed;
        m_ballYVelocity = ct_ballSpeed * (uniform(0, 2) % 2 ? -1 : 1);

        m_roundOver = false;
    }

    @trusted
    void pollEvent()
    {
        SDL_Event event;
        const(ubyte)* keys;

        if (!SDL_PollEvent(&event))
            return;

        switch (event.type)
        {
        case SDL_KEYDOWN:
        case SDL_KEYUP:
            {
                keys = SDL_GetKeyState(null);
                onKeyboardChanged(keys);
            }
            break;
        case SDL_QUIT:
            {
                stderr.writeln("Got SQL_QUIT event");
                m_quit = true;
            }
            break;
        default:
            break;
        }
    }

    @trusted
    void onKeyboardChanged(const ubyte* keys)
    {
        if (keys[SDLK_ESCAPE] == SDL_PRESSED)
        {
            stderr.writeln("Got ESCAPE key");
            m_quit = true;
        }

        if (keys[SDLK_s] == SDL_PRESSED)
        {
            stderr.writeln("Got S key");
            if (!m_hasBall)
            {
                m_hasBall = true;
                m_roundOver = true;
            }
        }

        if (keys[SDLK_UP] == SDL_PRESSED)
            m_paddleYVelocity = -ct_paddleSpeed;
        else if (keys[SDLK_DOWN] == SDL_PRESSED)
            m_paddleYVelocity = ct_paddleSpeed;
        else if (keys[SDLK_UP] == SDL_RELEASED && keys[SDLK_DOWN] == SDL_RELEASED)
            m_paddleYVelocity = 0;
    }

    @trusted
    void tick()
    {
        movePaddle;

        if (m_hasBall)
        {
            moveBall;
        }

        // Receive all messages from net thread to keep it happy, even if
        // we won't use them.
        Nullable!(Net.Message) nullableMsg = pollNetBall;

        if (!m_hasBall && !nullableMsg.isNull)
        {
            Net.Message msg = nullableMsg.get;
            switch (msg[0])
            {
            case NetMessageTypes.PASS:
                {
                    short yPos      = (cast(short[]) cast(void[]) msg[1 .. 3])[0];
                    short xVelocity = (cast(short[]) cast(void[]) msg[3 .. 5])[0];
                    short yVelocity = (cast(short[]) cast(void[]) msg[5 .. 7])[0];

                    m_hasBall = true;
                    m_ballRect.x = 0;
                    m_ballRect.y = yPos;
                    m_ballXVelocity = xVelocity;
                    m_ballYVelocity = yVelocity;
                }
                break;
            case NetMessageTypes.LOST:
                {
                    m_roundOver = true;
                    m_hasBall = true;
                }
                break;
            case NetMessageTypes.RESET:
                {
                    m_roundOver = true;
                    // TODO: reset score
                }
                break;
            default:
                stderr.writefln!"Unknown message type %02x"(msg[0]);
                break;
            }
        }
    }

    void movePaddle()
    {
        m_paddleRect.y += m_paddleYVelocity;
        m_paddleRect.y = cast(short) clamp(cast(int) m_paddleRect.y, 0, ct_fieldHeight - ct_paddleHeight - 1);
    }

    void moveBall()
    in (m_hasBall)
    {
        m_ballRect.x += m_ballXVelocity;
        m_ballRect.y += m_ballYVelocity;

        if (m_ballRect.x < 0)
        {
            // Hit left edge
            m_hasBall = false;
            // TODO: network
        }
        if (m_ballRect.x >= ct_fieldWidth - ct_ballWidth)
        {
            // Hit right edge
            m_roundOver = true;
        }
        if (m_ballRect.y < 0)
        {
            // Hit top edge
            m_ballYVelocity = abs(m_ballYVelocity);
        }
        if (m_ballRect.y >= ct_fieldHeight - ct_ballHeight)
        {
            // Hit bottom edge
            m_ballYVelocity = -abs(m_ballYVelocity);
        }

        m_ballRect.x = cast(short) clamp(cast(int) m_ballRect.x, 0, ct_fieldWidth - ct_ballWidth - 1);
        m_ballRect.y = cast(short) clamp(cast(int) m_ballRect.y, 0, ct_fieldHeight - ct_ballHeight - 1);

        if (m_ballRect.x + ct_ballWidth >= ct_paddleXPos 
            && inRange(m_ballRect.y, m_paddleRect.y, m_paddleRect.y + ct_paddleHeight))
        {
            m_ballRect.x = cast(short) (m_paddleRect.x - ct_ballWidth);
            m_ballXVelocity = -abs(m_ballXVelocity);
        }
    }

    @trusted
    Nullable!(Net.Message) pollNetBall()
    {
        Nullable!(Net.Message) nullableMsg;

        try
        {
            bool result;
            do
            {
                result = receiveTimeout(Duration.zero,
                    (Net.Message m) => nullableMsg = m,
                );
            } while (result);
        }
        catch (OwnerTerminated e)
        {
            stderr.writefln!"Net thread terminated: %s"(e);
            exit(1);
        }

        return nullableMsg;
    }

    static @trusted
    void netThreadEntrypoint(string networkInterface, string localAddress, string remoteAddress)
    {
        while (true)
        {
            try
            {
                Net net = Net(
                    captureDevName: networkInterface,
                    localAddress: localAddress,
                    remoteAddress: remoteAddress,
                );
                Net.Message message = net.receive;
                ownerTid.send(message);

            }
            catch (Exception e)
            {
                stderr.writefln!"net thread: caught Exception: %s"(e);
                Thread.sleep(1.seconds);
            }
        }
    }

    @trusted
    void draw()
    {
        SDL_FillRect(m_screen, &m_oldPaddleRect, fromRGB(ct_backgroundColor));
        SDL_FillRect(m_screen, &m_oldBallRect,   fromRGB(ct_backgroundColor));
        SDL_FillRect(m_screen, &m_paddleRect,    fromRGB(ct_paddleColor));
        SDL_FillRect(m_screen, &m_ballRect,      fromRGB(m_hasBall ? ct_ballColor : ct_backgroundColor));
        SDL_UpdateRects(m_screen, 4, &m_oldPaddleRect);
        m_oldPaddleRect = m_paddleRect;
        m_oldBallRect = m_ballRect;
    }

    @trusted
    uint fromRGB(const uint rgb)
    {
        const ubyte r = (rgb >> 0)  & 0xFF;
        const ubyte g = (rgb >> 8)  & 0xFF;
        const ubyte b = (rgb >> 16) & 0xFF;
        return SDL_MapRGB(m_screen.format, r, g, b);
    }
}
