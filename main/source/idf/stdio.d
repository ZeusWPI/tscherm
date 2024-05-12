module idf.stdio;

@safe nothrow @nogc:

pragma(printf) extern (C) @trusted
int printf(scope const char* fmt, scope const...);
