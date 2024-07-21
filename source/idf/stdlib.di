module idf.stdlib;

@safe nothrow @nogc:

extern (C)
{
    void* malloc(size_t);
    void free(void*);

    int atoi(const char*);
    long atol(const char*);
}
