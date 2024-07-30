module app.pong.tcp_server;

import app.pong.drawer;

import idf.errno : EAGAIN, errno;
import idf.freertos : vTaskDelay;
import idf.sys.socket : AF_INET, bind, htonl, htons, IPADDR_ANY, IPPROTO_UDP, recvfrom,
    MSG_DONTWAIT, SOCK_DGRAM, sockaddr, sockaddr_in, socket;

import idfd.log : Logger;

@safe nothrow @nogc:

struct PongTcpServer
{
    private enum log = Logger!"ChatHttpServer"();

    private PongDrawer* m_pongDrawer;
    private ushort m_port;
    private int m_socket;

scope:
    this(return scope PongDrawer* pongDrawer, ushort port = 777)
    in (pongDrawer !is null)
    {
        m_pongDrawer = pongDrawer;
        m_port = port;
    }

    @trusted
    void start()
    {
        m_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        assert(m_socket >= 0);

        {
            sockaddr_in bindAddr;
            bindAddr.sin_family = AF_INET;
            bindAddr.sin_addr.s_addr = htonl(IPADDR_ANY);
            bindAddr.sin_port = htons(m_port);

            int bindResult = bind(m_socket, cast(sockaddr*)&bindAddr, bindAddr.sizeof);
            assert(bindResult == 0);
        }
    }

    @trusted
    void recvOnce()
    {
        static ubyte[16] buf;
        sockaddr_in other;
        int received = recvfrom(m_socket, &buf[0], buf.length, MSG_DONTWAIT, null, null);

        if (received > 0)
        {
            log.info!"Got %d bytes: %.*s"(received, received, &buf[0]);
        }
    }
}
