// dfmt off
module net;

import core.sys.posix.arpa.inet : htonl, htons, INET_ADDRSTRLEN, inet_ntop, inet_pton, ntohl;
import core.sys.posix.netdb : gethostbyname, getprotobyname, hostent, protoent;
import core.sys.posix.netinet.in_ : sockaddr, sockaddr_in;
import core.sys.posix.sys.socket : AF_INET, sendto, SOCK_RAW, socket;
import core.sys.posix.unistd : unistdClose = close;

import std.format : f = format;
import std.stdio : stderr, stdout, write, writef, writefln, writeln;
import std.string : fromStringz, toStringz;
import std.range : chunks;

import importc.pcap : PCAP_ERRBUF_SIZE,PCAP_NETMASK_UNKNOWN,
    bpf_program, pcap_t, pcap_pkthdr,
    pcap_activate, pcap_breakloop, pcap_close, pcap_compile, pcap_create, pcap_geterr, pcap_loop,
    pcap_set_buffer_size, pcap_set_promisc, pcap_set_snaplen, pcap_set_timeout, pcap_setfilter;


private @safe:

debug = net;

public
struct NetRx
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

    @disable this();
    @disable this(ref typeof(this));

    /** 
     * Throws: NetException
     */
    public
    this(string captureDevName, string localHost, string remoteHost)
    {
        m_captureDevName = captureDevName;
        m_localAddress = localHost;
        m_remoteAddress = remoteHost;

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

    public
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
        NetRx* instance = cast(NetRx*) userArg;

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
struct NetTx
{
private:
    uint m_remoteIpv4Address;
    int m_socket = -1;
    
    @disable this();
    @disable this(ref typeof(this));

    public
    this(string remoteHost)
    {
        m_remoteIpv4Address = resolveIpv4Host(remoteHost);

        scope (failure) close;
        createSocket;
    }
    
    public @trusted
    void send(NetRx.Message msg)
    in (m_socket >= 0)
    {
        ubyte[NetRx.ct_icmpHeaderLength] icmpHeader;
        ubyte[NetRx.ct_contentLength] content;

        icmpHeader[0] = 0x08; // Type
        icmpHeader[1] = 0x00; // Code
        (cast(ushort[1]) icmpHeader[2 .. 4])[] = 0x0000.htons; // Checksum
        (cast(ushort[1]) icmpHeader[4 .. 6])[] = 0x0000.htons; // Identifier
        (cast(ushort[1]) icmpHeader[6 .. 8])[] = 0x0000.htons; // Sequence number

        cast(char[NetRx.ct_magic.length]) content[0 .. NetRx.ct_magic.length] = NetRx.ct_magic;
        content[NetRx.ct_magic.length .. $] = msg;

        ubyte[icmpHeader.sizeof + content.sizeof] buf = icmpHeader ~ content;

        (cast(ushort[1]) buf[2 .. 4])[] = icmpChecksum(buf).htons; // Checksum

        sockaddr_in sin = {
            sin_family: AF_INET,
            sin_port: 0,
            sin_addr: {
                s_addr: m_remoteIpv4Address.htonl,
            },
        };
        
        ptrdiff_t sent = m_socket.sendto(
            &buf[0], buf.sizeof,
            0,
            cast(sockaddr*) &sin, sin.sizeof
        );

        if (sent != buf.sizeof)
            throw new NetException("send failed");
    }

    public
    ~this()
    {
        close;
    }

    static @trusted
    uint resolveIpv4Host(string host)
    {
        // hostent* result = gethostbyname(host.toStringz);
        // if (result !is null || result.h_addr_list is null || result.h_addr_list[0] is null)
        //     throw new NetException(f!"Failed to resolve host %s"(host));
        // if (result.h_length != 4)
        //     throw new NetException(f!"Unexpected resolved address length");
        // void[4] ipv4AddressBytes = result.h_addr_list[0][0 .. 4];

        ubyte[4] ipv4AddressBytes;
        if (inet_pton(AF_INET, host.toStringz, &ipv4AddressBytes[0]) != 1)
            throw new NetException("Only ipv4 addresses are supported");
        return (cast(uint[1]) cast(void[4]) ipv4AddressBytes)[0].ntohl;
    }

    @trusted
    void createSocket()
    {
        protoent* icmpProtoEnt = getprotobyname("ICMP");
        assert(icmpProtoEnt !is null);
        m_socket = socket(AF_INET, SOCK_RAW, icmpProtoEnt.p_proto);
    }

 
    static
    ushort icmpChecksum(const ubyte[] ubyteBuf) {
        uint sum;
        foreach (chunk; ubyteBuf.chunks(2))
        {
            sum += chunk[0] << 8;
            if (chunk.length > 1)
                sum += chunk[1];
        }
        while (sum >> 16)
        {
            sum = (sum & 0xffff) + (sum >> 16);
        }
        return cast(ushort) ~sum;
    }
    
    void close()
    {
        if (m_socket >= 0)
        {
            unistdClose(m_socket);
        }
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
