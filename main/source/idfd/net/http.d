module idfd.net.http;

import idf.errno : EAGAIN, errno;
import idf.esp_timer : esp_timer_get_time;
import idf.stdio : printf;
import idf.stdlib : atoi;
import idf.sys.socket : accept, AF_INET, bind, close, connect, htonl, htons, IPADDR_ANY, IPPROTO_IP, listen,
    MSG_DONTWAIT, recv, send, shutdown, SOCK_STREAM, sockaddr, sockaddr_in, socket, socklen_t;

import ministd.memory : dallocArray, UniqueHeapArray;
import ministd.string : startsWith;

@safe nothrow @nogc:

struct HttpServer
{
    private ushort m_port;
    private int m_listenSocket;
    private long m_recvTimeoutUsecs;

    @disable this();

    this(ushort port, long recvTimeoutUsecs = 2_000_000)
    {
        m_port = port;
        m_recvTimeoutUsecs = recvTimeoutUsecs;
    }

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

        printf("HttpServer listening on port %hd\n", m_port);

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
            private long m_recvTimeoutUsecs;
            private bool m_isOpen = true;
            private bool m_timedOut;
            private bool m_calledEmpty;
            private UniqueHeapArray!C m_buf;
            private int m_received;
            private int m_currIndex;

            @disable this();

            this(in int socket, in long recvTimeoutUsecs)
            {
                m_socket = socket;
                m_recvTimeoutUsecs = recvTimeoutUsecs;
                m_buf = dallocArray!C(1024);
            }

            C front() const pure
            in (m_calledEmpty && m_isOpen)
            {
                return m_buf.get[m_currIndex];
            }

            void popFront() pure
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
                        long startTime = esp_timer_get_time;
                        while (true)
                        {
                            m_received = recv(m_socket, &m_buf.get[0], m_buf.get.length, MSG_DONTWAIT);
                            if (m_received > 0)
                                break;
                            if (m_received == 0 || (m_received < 0 && errno != EAGAIN))
                            {
                                m_isOpen = false;
                                break;
                            }
                            else if (esp_timer_get_time < startTime + m_recvTimeoutUsecs)
                            {
                                continue;
                            }
                            else
                            {
                                m_isOpen = false;
                                m_timedOut = true;
                                break;
                            }
                        }
                        m_currIndex = 0;
                    }
                }

                return !m_isOpen;
            }

            bool timedOut() const pure => m_timedOut;

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

        auto r = SocketReader!char(socket, m_recvTimeoutUsecs);

        void socketSend(C)(C[] data) @trusted
        {
            // TODO: timeout
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

        void send408()
        {
            printf("HttpServer.handleOurOnlyClient: Client took too long to send\n");
            printf("HttpServer.handleOurOnlyClient: Sending 408\n");
            socketSend(
                "HTTP/1.1 408 Request Timeout\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 19\r\n" ~
                    "\r\n" ~
                    "408 Request Timeout"
            );
        }

        UniqueHeapArray!char firstLineBuf = dallocArray!char(64);
        char[] firstLine = r.readLine(firstLineBuf.get);

        if (r.timedOut)
        {
            send408;
            return;
        }
        else if (firstLine.startsWith("GET /hello"))
        {
            printf("HttpServer.handleOurOnlyClient: Handling GET /hello\n");
            socketSend(
                "HTTP/1.1 200 OK\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 6\r\n" ~
                    "\r\n" ~
                    "Hello!"
            );
        }
        else if (firstLine.startsWith("POST /message"))
        {
            printf("HttpServer.handleOurOnlyClient: Handling POST /message\n");

            int contentLength = -1;
            {
                UniqueHeapArray!char headerLineBuf = dallocArray!char(256);
                while (true)
                {
                    char[] line = r.readLine(headerLineBuf.get);
                    if (line.length == 0)
                    {
                        if (r.timedOut)
                            send408;
                        return;
                    }
                    else if (line == "\r\n" || line == "\n")
                        break;
                    else if (line.startsWith("Content-Length: ")
                        || line.startsWith("content-length: "))
                    {
                        bool crlf = line[$ - 2 .. $] == "\r\n";
                        char[] numberString = line["Content-Length: ".length .. $ - (crlf ? 2 : 1)];
                        if (numberString.length > 3)
                        {
                            printf(
                                "HttpServer.handleOurOnlyClient: Message too long, sending 400\n");
                            socketSend(
                                "HTTP/1.1 400 Bad Request\r\n" ~
                                    "Content-Type: text/plain\r\n" ~
                                    "Content-Length: 16\r\n" ~
                                    "\r\n" ~
                                    "Message too long"
                            );
                            return;
                        }
                        else if (numberString.length >= 1)
                        {
                            char[4] numberStringz;
                            numberStringz[0 .. numberString.length] = numberString;
                            (() @trusted => contentLength = atoi(&numberStringz[0]))();
                        }
                    }
                }
            }
            if (contentLength < 0)
            {
                printf("HttpServer.handleOurOnlyClient: No Content-Length found, sending 400\n");
                socketSend("HTTP/1.1 400 Bad Request\r\n\r\n");
                return;
            }

            UniqueHeapArray!char bodyBuf = dallocArray!char(1024);
            char[] body;
            while (body.length != contentLength)
            {
                if (r.empty)
                {
                    printf("HttpServer.handleOurOnlyClient: Body smaller than Content-Length\n");
                    socketSend("HTTP/1.1 400 Bad Request\r\n\r\n");
                    return;
                }
                bodyBuf.get[body.length] = r.front;
                body = bodyBuf.get[0 .. body.length + 1];
                r.popFront;
            }

            printf("HttpServer.handleOurOnlyClient: Got body %s\n", &body[0]);

            socketSend("HTTP/1.1 204 No Content\r\n\r\n");
        }
        else
        {
            printf("HttpServer.handleOurOnlyClient: Sending 404\n");
            socketSend(
                "HTTP/1.1 404 Not Found\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 13\r\n" ~
                    "\r\n" ~
                    "404 Not Found"
            );
        }
    }
}
