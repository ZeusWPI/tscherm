module idfd.net.http_alt;

import idf.stdio : printf;
import idf.sys.socket : accept, AF_INET, bind, close, connect, getsockopt, htonl, htons, inet_pton, IPADDR_ANY, IPPROTO_IP, listen, perror, recv, send, setsockopt, shutdown, SO_RCVTIMEO, SO_SNDTIMEO, SOCK_STREAM, sockaddr, sockaddr_in, socket, socklen_t, SOL_SOCKET, timeval;

import idfd.util;

@safe:

struct HttpServer
{
    private ushort m_port;
    private int m_listenSocket;

    @disable this();

    this(ushort port)
    {
        m_port = port;
    }

    // private void setSockOpts(in int socket) @trusted
    // {
    //     timeval val;
    //     socklen_t valSize = val.sizeof;
        
    //     if (getsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &val, &valSize) != 0)
    //         perror("getsockopt SO_RCVTIMEO failed");

    //     // val.tv_sec = 3;
    //     // val.tv_usec = 0;

    //     if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &val, valSize) != 0)
    //         perror("setsockopt SO_RCVTIMEO failed");

    //     // if (setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &val, valSize) != 0)
    //     //     perror("setsockopt SO_SNDTIMEO failed");
    // }

    void start() @trusted
    {
        m_listenSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
        assert(m_listenSocket >= 0);

        {
            sockaddr_in bindAddr;
            bindAddr.sin_family = AF_INET;
            bindAddr.sin_addr.s_addr = htonl(IPADDR_ANY);
            bindAddr.sin_port = htons(m_port);

            int bindResult = bind(m_listenSocket, cast(sockaddr*)&bindAddr, bindAddr.sizeof);
            assert(bindResult == 0);
        }

        {
            int listenResult = listen(m_listenSocket, /*backlog:*/ 1);
            assert(listenResult == 0);
        }

        printf("HttpServer listening on port %hd...\n", m_port);

        while (true)
        {
            sockaddr_in sourceAddr;
            socklen_t sourceAddrSize = sourceAddr.sizeof;
            int socket = accept(m_listenSocket, cast(sockaddr*)&sourceAddr, &sourceAddrSize);
            assert(socket >= 0);

            handleOurOnlyClient(socket);

            shutdown(socket, 0);
            close(socket);
        }
    }

    void handleOurOnlyClient(int socket)
    {
        printf("HttpServer.handleOurOnlyClient: Started\n");
        scope (exit)
            printf("HttpServer.handleOurOnlyClient: Exited\n\n");

        struct SocketReader(C = char) if (C.sizeof == 1)
        {
            private int m_socket = -1;
            private bool m_isOpen = true;
            private bool m_calledEmpty = false;
            private C[1024] m_buf;
            private int m_received;
            private int m_currIndex;

            @disable this();

            this(in int socket)
            {
                m_socket = socket;
            }

            C front()
            in (m_calledEmpty && m_isOpen)
            {
                return m_buf[m_currIndex];
            }

            void popFront()
            in (m_calledEmpty && m_isOpen)
            {
                m_currIndex++;
                m_calledEmpty = false;
            }

            bool empty() @trusted
            {
                m_calledEmpty = true;

                if (m_isOpen)
                {
                    if (m_received == m_currIndex)
                    {
                        m_received = recv(m_socket, &m_buf[0], m_buf.sizeof, 0);
                        m_currIndex = 0;
                        if (m_received <= 0)
                            m_isOpen = false;
                    }
                }

                return !m_isOpen;
            }

            C[] readLine(scope C[] buf)
            {
                foreach (i, ref c; buf)
                {
                    if (empty)
                        return [];
                    c = front;
                    popFront;
                    if (c == '\n')
                        return buf[0 .. i + 1];
                }
                return buf;
            }
        }

        auto r = SocketReader!char(socket);

        void socketSend(C)(C[] data) @trusted
        {
            int totalSent;
            while (totalSent != data.length)
            {
                assert(totalSent < data.length);

                int sent = send(socket, &data[0], data.length, 0);
                if (sent >= 0)
                    totalSent += sent;
                else
                    return;
            }
        }

        char[64] firstLineBuf;
        char[] firstLine = r.readLine(firstLineBuf[]);

        if (firstLine.startsWith("GET /hello"))
        {
            printf("HttpServer.handleOurOnlyClient: Handled GET /hello\n");
            socketSend(
                "HTTP/1.1 200 OK\n" ~
                    "Content-Type: text/plain\n" ~
                    "Content-Length: 6\n" ~
                    "\n" ~
                    "Hello!"
            );
        }
        else
        {
            printf("HttpServer.handleOurOnlyClient: Sending 404\n");
            socketSend(
                "HTTP/1.1 404 Not Found\n" ~
                    "Content-Type: text/plain\n" ~
                    "Content-Length: 13\n" ~
                    "\n" ~
                    "404 Not Found"
            );
        }
    }
}
