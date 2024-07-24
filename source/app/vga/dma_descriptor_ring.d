module app.vga.dma_descriptor_ring;

import idf.esp_rom.lldesc : lldesc_t;
import idf.heap.caps : MALLOC_CAP_DMA;

import ministd.heap_caps : dallocArrayCaps;

@safe nothrow @nogc:
// dfmt off

struct DMADescriptorRing
{
nothrow @nogc:
    private lldesc_t[] m_descriptors;

scope:
    this(in size_t descriptorCount)
    {
        initDescriptors(descriptorCount);
    }

    private
    void initDescriptors(size_t descriptorCount)
    {
        // Alloc structs
        m_descriptors = dallocArrayCaps!lldesc_t(descriptorCount, MALLOC_CAP_DMA);
        // Init structs
        foreach (ref descriptor; m_descriptors)
        {
            descriptor.length = 0;
            descriptor.size = 0;
            descriptor.sosf = 0;
            descriptor.eof = 1;
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
        foreach (i, ref descriptor; m_descriptors)
        {
            ubyte[] buf = buffers[i];
            descriptor.length = cast(uint) buf.length;
            descriptor.size = cast(uint) buf.length;
            descriptor.buf = cast(ubyte*) &buf[0];
        }
    }

    pure
    lldesc_t* firstDescriptor() return scope => &m_descriptors[0];
}
