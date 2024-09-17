// Rewritten NETPONG based on https://archive.org/details/tucows_11948_netPONG
// Compile with: cc -I/usr/local/include -L/usr/local/lib -lSDL netpong.c -o netpong -std=c11 -O3 -s

#include <SDL/SDL.h>
#include <stdio.h>
#include <assert.h>

#define SDL_clamp(val, lower, upper) SDL_min(SDL_max(val, lower), (upper) - 1)
#define SDL_inRange(val, lower, upper) ((lower) <= (val) && (val) < (upper))

#define ct_fps 75

#define ct_width 1024
#define ct_height 768

#define ct_backgroundColor 0x000000U
#define ct_borderColor 0x808080U
#define ct_paddleColor 0xFFFFFFU
#define ct_ballColor 0xC0C0C0U

#define ct_fieldWidth ct_width
#define ct_fieldHeight ct_height

#define ct_paddleWidth (ct_fieldWidth / 40)
#define ct_paddleHeight (ct_fieldHeight / 5)
#define ct_paddleXPos (ct_fieldWidth - ct_paddleWidth)
#define ct_paddleSpeed ((Sint32)(ct_height * 60 / (120 * ct_fps)))

#define ct_ballRadius (ct_height / 240) // 0 For a single pixel
#define ct_ballWidth (1 + 2 * ct_ballRadius)
#define ct_ballHeight ct_ballWidth
#define ct_ballSpeed ((Sint32)(ct_width * 60 / (128 * ct_fps)))

typedef struct
{
    SDL_Surface *screen;
    // Don't change field order
    SDL_Rect oldPaddleRect, oldBallRect;
    SDL_Rect paddleRect, ballRect;
    Sint32 paddleYVelocity, ballXVelocity, ballYVelocity;
    Uint32 lastFrameTick;
    SDL_bool gameOver, quit;
} pong_t;

void pongInit(pong_t *pong)
{
    memset(pong, 0, sizeof(pong_t));

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
        exit(1);
    }
    atexit(SDL_Quit);

    pong->screen = SDL_SetVideoMode(ct_width, ct_height, 16, SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE | SDL_FULLSCREEN);
    if (pong->screen == NULL)
    {
        fprintf(stderr, "Unable to set video mode: %s\n", SDL_GetError());
        exit(1);
    }

    SDL_WM_SetCaption("NETPONG", NULL);

    pong->paddleRect.w = ct_paddleWidth;
    pong->paddleRect.h = ct_paddleHeight;
    pong->ballRect.w = ct_ballWidth;
    pong->ballRect.h = ct_ballHeight;
    pong->oldPaddleRect = pong->paddleRect;
    pong->oldBallRect = pong->ballRect;
}

Uint32 pongRGB(const pong_t *pong, const Uint32 rgb)
{
    const Uint8 r = (rgb >> 0) & 0xFF;
    const Uint8 g = (rgb >> 8) & 0xFF;
    const Uint8 b = (rgb >> 16) & 0xFF;
    return SDL_MapRGB(pong->screen->format, r, g, b);
}

void pongReset(pong_t *pong)
{
    pong->paddleRect.x = ct_fieldWidth - 1 - ct_paddleWidth;
    pong->paddleRect.y = (ct_fieldHeight - ct_paddleHeight) / 2;

    pong->ballRect.x = (ct_fieldWidth - ct_ballWidth) / 2;
    pong->ballRect.y = (ct_fieldHeight - ct_ballHeight) / 2;

    pong->ballXVelocity = ct_ballSpeed;
    pong->ballYVelocity = ct_ballSpeed * (rand() % 2 ? -1 : 1);

    pong->gameOver = SDL_FALSE;

    SDL_FillRect(pong->screen, NULL, pongRGB(pong, ct_backgroundColor));
    SDL_UpdateRect(pong->screen, 0, 0, 0, 0);
}

void pongKeyboardChanged(pong_t *pong, const Uint8 *keys)
{
    if (keys[SDLK_ESCAPE] == SDL_PRESSED)
    {
        fprintf(stderr, "Got ESCAPE key\n");
        pong->quit = SDL_TRUE;
    }

    if (keys[SDLK_UP] == SDL_PRESSED)
        pong->paddleYVelocity = -ct_paddleSpeed;
    else if (keys[SDLK_DOWN] == SDL_PRESSED)
        pong->paddleYVelocity = ct_paddleSpeed;
    else if (keys[SDLK_UP] == SDL_RELEASED && keys[SDLK_UP] == SDL_RELEASED)
        pong->paddleYVelocity = 0;
}

void pongPollEvent(pong_t *pong)
{
    SDL_Event event;
    const Uint8 *keys;
    if (!SDL_PollEvent(&event))
        return;
    switch (event.type)
    {
    case SDL_KEYDOWN:
    case SDL_KEYUP:
        keys = SDL_GetKeyState(NULL);
        pongKeyboardChanged(pong, keys);
        break;
    case SDL_QUIT:
        fprintf(stderr, "Got SQL_QUIT event\n");
        pong->quit = SDL_TRUE;
        break;
    default:
        break;
    }
}

void pongTick(pong_t *pong)
{
    // Move paddle
    pong->paddleRect.y += pong->paddleYVelocity;
    pong->paddleRect.y = SDL_clamp(pong->paddleRect.y, 0, ct_fieldHeight - ct_paddleHeight);

    // Move ball
    pong->ballRect.x += pong->ballXVelocity;
    pong->ballRect.y += pong->ballYVelocity;

    if (pong->ballRect.x < 0)
    {
        // Hit left edge
        pong->ballXVelocity = SDL_abs(pong->ballXVelocity);
    }
    if (pong->ballRect.x >= ct_fieldWidth - ct_ballWidth)
    {
        // Hit right edge
        pong->gameOver = SDL_TRUE;
    }
    if (pong->ballRect.y < 0)
    {
        // Hit top edge
        pong->ballYVelocity = SDL_abs(pong->ballYVelocity);
    }
    if (pong->ballRect.y >= ct_fieldHeight - ct_ballHeight)
    {
        // Hit bottom edge
        pong->ballYVelocity = -SDL_abs(pong->ballYVelocity);
    }

    pong->ballRect.x = SDL_clamp(pong->ballRect.x, 0, ct_fieldWidth - ct_ballWidth);
    pong->ballRect.y = SDL_clamp(pong->ballRect.y, 0, ct_fieldHeight - ct_ballHeight);

    if (pong->ballRect.x + ct_ballWidth >= ct_paddleXPos &&
        SDL_inRange(pong->ballRect.y, pong->paddleRect.y, pong->paddleRect.y + ct_paddleHeight))
    {
        pong->ballRect.x = pong->paddleRect.x - ct_ballWidth;
        pong->ballXVelocity = -SDL_abs(pong->ballXVelocity);
    }
}

void pongDraw(pong_t *pong)
{
    SDL_FillRect(pong->screen, &pong->oldPaddleRect, pongRGB(pong, ct_backgroundColor));
    SDL_FillRect(pong->screen, &pong->oldBallRect, pongRGB(pong, ct_backgroundColor));
    SDL_FillRect(pong->screen, &pong->paddleRect, pongRGB(pong, ct_paddleColor));
    SDL_FillRect(pong->screen, &pong->ballRect, pongRGB(pong, ct_ballColor));
    SDL_UpdateRects(pong->screen, 4, &pong->oldPaddleRect);
    pong->oldPaddleRect = pong->paddleRect;
    pong->oldBallRect = pong->ballRect;
}

void pongRun(pong_t *pong)
{
    while (!pong->quit)
    {
        pongReset(pong);
        while (!pong->gameOver)
        {
            do
            {
                pongPollEvent(pong);
                if (pong->quit)
                    return;
            } while (SDL_GetTicks() - pong->lastFrameTick < 1000 / ct_fps);
            pong->lastFrameTick = SDL_GetTicks();

            pongTick(pong);

            if (pong->gameOver)
                break;

            pongDraw(pong);
        }
    }
}

int main(int argc, char *argv[])
{
    pong_t pong;
    pongInit(&pong);
    pongRun(&pong);
    return 0;
}
