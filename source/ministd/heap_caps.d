module ministd.heap_caps;

import ministd.traits : isAggregateType;

import core.lifetime : emplace;

import idf.heap.caps : heap_caps_malloc;

@safe nothrow @nogc:

@trusted
void[] mallocCapsWrapper(size_t size, uint capabilities = 0)
{
    void* ptr = heap_caps_malloc(size, capabilities);
    if (ptr is null)
        assert(false, "malloc failed");
    return ptr[0 .. size];
}

@trusted
T* dallocCaps(T)(uint capabilities = 0, T initValue = T.init) // POD version
if (T.sizeof && !isAggregateType!T)
{
    void[] allocatedHeapMem = mallocCapsWrapper(T.sizeof, capabilities);
    T* ptr = cast(T*) allocatedHeapMem.ptr;
    *ptr = initValue;
    return ptr;
}

@trusted
T* dallocCaps(T, CtorArgs...)(uint capabilities = 0, CtorArgs ctorArgs) // Struct/union version
if (T.sizeof && (is(T == struct) || is(T == union)))
{
    void[] allocatedHeapMem = mallocCapsWrapper(T.sizeof, capabilities);
    allocatedHeapMem.emplace!T(ctorArgs);
    return cast(T*) ptr;
}

@trusted
T[] dallocArrayCaps(T)(size_t length, uint capabilities = 0, T initValue = T.init) // POD version
if (T.sizeof && !isAggregateType!T)
{
    void[] allocatedHeapMem = mallocCapsWrapper(T.sizeof * length, capabilities);
    T[] slice = cast(T[]) allocatedHeapMem;
    foreach (ref T el; slice)
        el = initValue;
    return slice;
}

@trusted
T[] dallocArrayCaps(T, CtorArgs...)(size_t length, uint capabilities = 0, CtorArgs ctorArgs) // Struct/union version
if (T.sizeof && (is(T == struct) || is(T == union)))
{
    void[] allocatedHeapMem = mallocCapsWrapper(T.sizeof * length, capabilities);
    T[] slice = cast(T[]) allocatedHeapMem;
    foreach (ref T el; slice)
        (&el).emplace!T(ctorArgs);
    return slice;
}
