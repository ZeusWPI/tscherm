module app.pong.tcp_server;

import app.pong.drawer;

import idf.errno : EAGAIN, errno;
import idf.freertos : vTaskDelay;
import idf.sys.socket : AF_INET, bind, close, htonl, htons, IPADDR_ANY, IPPROTO_UDP, recvfrom,
    SOCK_DGRAM, sockaddr, sockaddr_in, socket;

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

        static ubyte[16] buf;
        int iteration;
        while (true)
        {
            sockaddr_in other;
            int received = recvfrom(m_socket, &buf[0], buf.length, 0, null, null);

            if (received <= 0)
            {
                close(m_socket);
                log.info!"Socket closed";
                break;
            }
            if (received > 0)
            {
                // log.info!"Got %d bytes: %.*s"(received, received, &buf[0]);
                foreach (ubyte b; buf[0 .. received])
                {
                    log.info!"%c"(b);
                    m_pongDrawer.clearBar;
                    if (buf[0] == 'j')
                        m_pongDrawer.moveBarDown(16);
                    else if (buf[0] == 'k')
                        m_pongDrawer.moveBarUp(16);
                    m_pongDrawer.drawBar;
                }
            }
            if (++iteration == 1000)
            {
                iteration = 0;
                vTaskDelay(1);
            }
        }
    }
}
