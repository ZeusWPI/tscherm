module app.vga.dma_descriptor_ring;

import idf.esp_rom.lldesc : lldesc_t;
import idf.heap.caps : MALLOC_CAP_DMA;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:

struct DMADescriptorRing
{
nothrow @nogc:
    private lldesc_t[] m_descriptors;

scope:
    @disable this();
    @disable this(ref typeof(this));

    void initialize(in size_t descriptorCount)
    {
        initDescriptors(descriptorCount);
    }

    private
    void initDescriptors(size_t descriptorCount)
    {
        // Alloc structs
        m_descriptors = dallocArrayCaps!lldesc_t(descriptorCount, MALLOC_CAP_DMA);
        // Init structs
        foreach (ref lldesc_t descriptor; m_descriptors)
        {
            descriptor.length = 0;
            descriptor.size = 0;
            descriptor.sosf = 0;
            descriptor.eof = 0;
            descriptor.owner = 1;
            descriptor.buf = null;
            descriptor.offset = 0;
            descriptor.empty = 0;
            (() @trusted => descriptor.qe.stqe_next = null)();
        }
        // Link them in a ring
        foreach (i; 0 .. m_descriptors.length)
        {
            lldesc_t* next = &m_descriptors[(i + 1) % m_descriptors.length];
            (() @trusted => m_descriptors[i].qe.stqe_next = next)();
        }
    }

    pure
    void setBuffers(ubyte[][] buffers)
    in (buffers.length == m_descriptors.length)
    {
        foreach (i, ref lldesc_t descriptor; m_descriptors)
        {
            ubyte[] buf = buffers[i];
            descriptor.length = cast(uint) buf.length;
            descriptor.size = cast(uint) buf.length;
            descriptor.buf = &buf[0];
        }
    }

    pure
    inout(lldesc_t)* firstDescriptor() inout return scope
        => &m_descriptors[0];

    pure
    inout(lldesc_t)[] descriptors() inout return scope
        => m_descriptors;
}
