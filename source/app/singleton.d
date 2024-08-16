module app.singleton;

@safe nothrow @nogc:

mixin template Singleton()
{
    static assert(is(typeof(this) == struct));
    static assert(is(typeof(&this.initialize) == void function()));

    private __gshared bool s_instanceInitialized;
    private __gshared TScherm s_instance;

    static @trusted
    void createInstance()
    in (!s_instanceInitialized)
    {
        s_instanceInitialized = true;
        s_instance.initialize;
    }

    static @trusted nothrow @nogc pragma(inline, true)
    ref TScherm instance()
    in (s_instanceInitialized)
        => s_instance;
}