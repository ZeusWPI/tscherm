// dfmt off
module net;

import core.sys.posix.arpa.inet;
import core.sys.posix.netdb;
import core.sys.posix.netinet.in_;
import core.sys.posix.sys.socket;

import std.format : f = format;
import std.stdio : stderr, stdout, write, writef, writefln, writeln;
import std.string : fromStringz, toStringz;

import importc.pcap : PCAP_ERRBUF_SIZE,PCAP_NETMASK_UNKNOWN,
    bpf_program, pcap_t, pcap_pkthdr,
    pcap_activate, pcap_breakloop, pcap_close, pcap_compile, pcap_create, pcap_geterr, pcap_loop,
    pcap_set_buffer_size, pcap_set_promisc, pcap_set_snaplen, pcap_set_timeout, pcap_setfilter;

private @safe:

debug = net;

public
struct Net
{
private:
    enum size_t ct_ethHeaderLength = 14;
    enum size_t ct_ipv4HeaderLength = 20;
    enum size_t ct_icmpHeaderLength = 8;
    enum size_t ct_contentLength = 15;
    enum size_t ct_totalPacketLength = ct_ethHeaderLength + ct_ipv4HeaderLength + ct_icmpHeaderLength
        + ct_contentLength;

    enum size_t ct_ethHeaderBegin = 0;
    enum size_t ct_ethHeaderEnd = ct_ethHeaderBegin + ct_ethHeaderLength;
    enum size_t ct_ipv4HeaderBegin = ct_ethHeaderEnd;
    enum size_t ct_ipv4HeaderEnd = ct_ipv4HeaderBegin + ct_ipv4HeaderLength;
    enum size_t ct_icmpHeaderBegin = ct_ipv4HeaderEnd;
    enum size_t ct_icmpHeaderEnd = ct_icmpHeaderBegin + ct_icmpHeaderLength;
    enum size_t ct_contentBegin = ct_icmpHeaderEnd;
    enum size_t ct_contentEnd = ct_contentBegin + ct_contentLength;

    enum string ct_magic = "NETPONG!";

    public alias Message = ubyte[7];
    static assert(Message.sizeof == ct_contentLength - ct_magic.length);

    string m_captureDevName;
    string m_localAddress;
    string m_remoteAddress;

    char[PCAP_ERRBUF_SIZE] errBuf = 0;
    pcap_t* m_captureDev;
    bpf_program m_captureFilter;
    Message loopResultMessage;

    /** 
     * Throws: NetException
     */
    public
    this(string captureDevName, string localAddress, string remoteAddress)
    {
        m_captureDevName = captureDevName;
        m_localAddress = localAddress;
        m_remoteAddress = remoteAddress;

        scope (failure) close;
        createCaptureDev;
    }

    /** 
     * Throws: NetException
     */
    public
    Message receive()
    {
        scope (exit) close;
        start;
        loop;
        return loopResultMessage;
    }

    public @trusted
    ~this()
    {
        close;
    }

    @trusted
    void createCaptureDev()
    {
        // pcap_t* captureDev = pcap_open_live(ct_captureDevName, BUFSIZ, 1, 100, errBuf);
        m_captureDev = pcap_create(m_captureDevName.toStringz, &errBuf[0]);
        checkPcap(m_captureDev);

        checkPcap(pcap_set_buffer_size(m_captureDev, 1024));
        checkPcap(pcap_set_snaplen(m_captureDev, 60));
        checkPcap(pcap_set_timeout(m_captureDev, 1));
        // checkPcap(pcap_set_promisc(m_captureDev, 1));
    }

    @trusted
    void start()
    {
        checkPcap(pcap_activate(m_captureDev));
        compileCaptureFilter;
        applyCaptureFilter;
    }

    @trusted
    void compileCaptureFilter()
    {
        string filterString = buildCaptureFilterString;
        checkPcap(pcap_compile(m_captureDev, &m_captureFilter,
            /*str:*/ filterString.toStringz,
            /*optimize:*/ 0,
            /*netmask:*/ PCAP_NETMASK_UNKNOWN,
        ));
    }

    string buildCaptureFilterString() const
    {
        return f!"icmp[icmptype]==icmp-echo and src host %s and dst host %s"(
            m_remoteAddress, m_localAddress,
        );
    }

    @trusted
    void applyCaptureFilter()
    {
        checkPcap(pcap_setfilter(m_captureDev, &m_captureFilter));
    }

    @trusted
    void loop()
    {
        pcap_loop(m_captureDev,
            /*cnt:*/ -1,
            /*callback:*/ &loopCallback,
            /*user:*/ cast(ubyte*) &this,
        );
    }

    static extern (C) @trusted
    void loopCallback(ubyte* userArg, const pcap_pkthdr* header, const ubyte* packet)
    {
        Net* instance = cast(Net*) userArg;

        if (header.len != header.caplen)
        {
            // Didn't fully capture packet, skip
            return;
        }
        if (header.len < ct_totalPacketLength)
        {
            // Can't be a packet for us, too small, skip
            return;
        }
        // Can't check if packet is too large, might have been padded

        const ubyte[] ethHeader  = packet[ct_ethHeaderBegin  .. ct_ethHeaderEnd];
        const ubyte[] ipv4Header = packet[ct_ipv4HeaderBegin .. ct_ipv4HeaderEnd];
        const ubyte[] icmpHeader = packet[ct_icmpHeaderBegin .. ct_icmpHeaderEnd];
        const ubyte[] content    = packet[ct_contentBegin    .. ct_contentEnd];

        { // Parse ethernet header
            // (Has nothing of interest)
        }

        uint sourceIpUint, destIpUint;
        char[INET_ADDRSTRLEN] sourceIpStringz, destIpStringz;
        char[] sourceIpString, destIpString;
        { // Parse ipv4 header
            sourceIpUint = (cast(uint[]) ipv4Header[12 .. 16])[0];
            destIpUint   = (cast(uint[]) ipv4Header[16 .. 20])[0];
            inet_ntop(AF_INET, &sourceIpUint, &sourceIpStringz[0], sourceIpStringz.sizeof);
            inet_ntop(AF_INET, &destIpUint, &destIpStringz[0], destIpStringz.sizeof);
            sourceIpString = sourceIpStringz.fromStringz;
            destIpString   = destIpStringz.fromStringz;
        }

        { // Parse icmp header
            // (Has nothing of interest)
        }

        char[] magic;
        Message message;
        { // Parse content
            magic = cast(char[]) content[0 .. ct_magic.length];
            message = content[ct_magic.length .. $];
        }

        debug (net) writefln!`Got a packet:`;
        debug (net) writefln!`  source ip = %s`(sourceIpString);
        debug (net) writefln!`  dest ip = %s`(destIpString);
        debug (net) writefln!`  magic = "%s"`(magic);
        debug (net) writefln!`  message = [%(0x%02x, %)]`(message);

        if (magic == ct_magic)
        {
            debug (net) writeln("Magic is correct, breaking loop and returning from receive().");
            instance.loopResultMessage = message;
            pcap_breakloop(instance.m_captureDev);
        }
    }

    @trusted
    void close()
    {
        if (m_captureDev !is null)
        {
            pcap_close(m_captureDev);
            m_captureDev = null;
        }
    }

    @trusted
    void checkPcap(int result)
    {
        if (result != 0)
        {
            string message;
            if (errBuf.fromStringz.length)
            {
                message = errBuf.fromStringz.idup;
            }
            else
            {
                char* stringz = pcap_geterr(m_captureDev);
                if (stringz !is null)
                    message = stringz.fromStringz.idup;
            }
            throw new NetException(f!`pcap function failed with code %d and message "%s"`(
                result, message,
            ));
        }
    }

    void checkPcap(void* ptr)
    {
        if (ptr is null)
            checkPcap(-1);
    }
}

public
class NetException : Exception
{
    pure nothrow @nogc
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
}
