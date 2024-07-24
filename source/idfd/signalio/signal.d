module idfd.signalio.signal;

@safe nothrow @nogc:

struct Signal
{
nothrow @nogc:
    private uint m_signal;

scope:
    this(uint signal)
    {
        m_signal = signal;
    }

    const pure
    {
        uint signal() => m_signal;
    }
}
