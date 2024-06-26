module ministd.memory;

import idf.heap.caps : heap_caps_malloc;
import idf.stdlib : free, malloc;

@safe:

//import idf.stdio : printf;
//static int mallocCalled = 0;

T* dalloc(T)() @trusted
{
    ubyte* ptr = cast(ubyte*) malloc(T.sizeof);
    //printf("dalloc: malloc called %d times\n", ++mallocCalled);
    assert(ptr, "dalloc: malloc failed");
    foreach (ref b; ptr[0 .. T.sizeof])
        b = 0;
    return cast(T*) ptr;
}

T[] dallocArray(T)(size_t length, ubyte initValue = 0) @trusted
{
    ubyte* ptr = cast(ubyte*) malloc(T.sizeof * length);
    //printf("dallocArray: malloc called %d times\n", ++mallocCalled);
    assert(ptr, "dallocArray: malloc failed");
    ubyte[] slice = ptr[0 .. T.sizeof * length];
    foreach (ref b; slice)
        b = initValue;
    return cast(T[]) slice;
}

T* dallocCaps(T)(uint capabilities = 0) @trusted
{
    ubyte* ptr = cast(ubyte*) heap_caps_malloc(T.sizeof, capabilities);
    //printf("dallocCaps: malloc called %d times\n", ++mallocCalled);
    assert(ptr, "dallocCaps: malloc failed");
    foreach (ref b; ptr[0 .. T.sizeof])
        b = 0;
    return cast(T*) ptr;
}

T[] dallocArrayCaps(T)(size_t length, uint capabilities = 0, ubyte initValue = 0) @trusted
{
    ubyte* ptr = cast(ubyte*) heap_caps_malloc(T.sizeof * length, capabilities);
    //printf("dallocArrayCaps: malloc called %d times\n", ++mallocCalled);
    assert(ptr, "dallocArrayCaps: malloc failed");
    ubyte[] slice = ptr[0 .. T.sizeof * length];
    foreach (ref b; slice)
        b = initValue;
    return cast(T[]) slice;
}

void dfree(T)(T* t) @trusted
{
    free(cast(void*) t);
}

void dfree(T)(T[] t) @trusted
{
    free(cast(void*) t.ptr);
}

T* move(T)(ref T* ptr)
{
    scope(exit) ptr = null;
    return ptr;
}

T[] move(T)(ref T[] slice)
{
    scope(exit) slice = [];
    return slice;
}

struct UniqueHeapPtr(T)
{
    private T* m_ptr;

    @disable this();
    @disable this(typeof(this));

    private

    this(T* ptr) pure
    {
        m_ptr = ptr;
    }

    ~this()
    {
        dfree(m_ptr);
    }

    static typeof(this) create(CtorArgs...)(CtorArgs ctorArgs)
    {
        T* ptr = dalloc!T;
        *ptr = T(ctorArgs);
        return typeof(this)(ptr);
    }

    bool empty() pure const => m_ptr is null;

    void reset()
    in (!empty)
    {
        dfree(m_ptr);
        m_ptr = null;
    }

    inout(T*) get() inout pure => m_ptr;
}

struct UniqueHeapArray(T)
{
    private T[] m_arr;

    @disable this();

    this(T[] arr) pure
    {
        m_arr = arr;
    }

    ~this()
    {
        static if (is(T == struct))
            foreach (el; m_arr)
                destroy(el);
        dfree(m_arr);
    }

    typeof(this) move()
    {
        return UniqueHeapArray(.move(m_arr));
    }

    static typeof(this) create(CtorArgs...)(size_t length, CtorArgs ctorArgs)
    {
        T[] arr = dallocArray!T(length);
        foreach (ref el; arr)
            el = T(ctorArgs);
        return typeof(this)(.move(arr));
    }

    bool empty() pure const => m_arr is [];

    void reset()
    in (!empty)
    {
        dfree(m_arr);
        m_arr = [];
    }

    inout(T[]) get() inout pure => m_arr;
}
