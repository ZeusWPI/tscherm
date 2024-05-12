module ministd.string;

enum string stringzOf(string S) = (S ~ '\0');
enum immutable(char)* stringzPtrOf(string S) = (S ~ '\0').ptr;

void setStringz(C1, C2)(C1[] target, in C2[] source)
if (C1.sizeof == 1 && C2.sizeof == 1)
in (target.length >= source.length + 1)
{
    target[0 .. source.length] = cast(const C1[]) source[];
    target[source.length] = 0;
}

UniqueHeapArray!char toStringz(S)(S s)
if (isSomeString!S)
out (ret; ret.get.length == s.length + 1)
{
    auto sz = typeof(return).create(s.length + 1);
    sz.get.setStringz(s);
    return sz.move;
}

bool startsWith(T)(in T[] a, in T[] b) pure
{
    return a.length >= b.length && a[0 .. b.length] == b;
}