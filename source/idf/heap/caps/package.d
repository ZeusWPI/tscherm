module idf.heap.caps;

public import idf.heap.caps.idf_heap_caps_c_code : MALLOC_CAP_DMA;

@safe nothrow @nogc:

extern(C)
void* heap_caps_malloc(size_t size, uint caps);