module idfd.signalio.signal;

@safe nothrow @nogc:

struct Signal
{
    uint m_signal;

    @disable this();

    this(uint signal)
    {
        m_signal = signal;
    }

    uint signal() pure const => m_signal;
}