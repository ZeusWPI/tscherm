module idfd.signalio.signal;

@safe nothrow @nogc:

struct Signal
{
    private uint m_signal;

    this(uint signal)
    {
        m_signal = signal;
    }

    pure const
    {
        uint signal() => m_signal;
    }
}
