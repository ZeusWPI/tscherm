module idfd.signalio.gpio;

import idfd.signalio.signal : Signal;

import ministd.math : inRange;

@safe nothrow @nogc:

struct GPIOPin
{
nothrow @nogc:
    enum FIRST_PIN = 0;
    enum LAST_PIN = 39;

    private uint m_pin;

scope:
    this(uint pin)
    in (pin.inRange!"[]"(FIRST_PIN, LAST_PIN))
    {
        m_pin = pin;
    }

    const pure
    {
        uint pin() => m_pin;
        bool supportsInput() => true;
        bool supportsOutput() => pin <= 33;
    }
}
