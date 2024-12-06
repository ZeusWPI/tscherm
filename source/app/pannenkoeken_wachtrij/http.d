module app.pannenkoeken_wachtrij.http;

import app.pannenkoeken_wachtrij.pannenkoeken_wachtrij : PannenkoekenWachtrij;

import idf.errno : EAGAIN, errno;
import idf.esp_timer : esp_timer_get_time;
import idf.stdlib : atoi;
import idf.sys.socket : accept, AF_INET, bind, close, connect, htonl, htons, IPADDR_ANY, IPPROTO_IP, listen,
    MSG_DONTWAIT, recv, send, shutdown, SOCK_STREAM, sockaddr, sockaddr_in, socket, socklen_t;

import idf.freertos : vTaskDelay;

import idfd.log : Logger;

import ministd.string : startsWith;
import ministd.traits : isInstanceOf;
import ministd.typecons : UniqueHeapArray;

@safe nothrow @nogc:

struct HttpServer(PannenkoekenWachtrijT) //
if (isInstanceOf!(PannenkoekenWachtrij, PannenkoekenWachtrijT))
{
    private enum log = Logger!"HttpServer"();

    private ushort m_port;
    private int m_listenSocket;
    private long m_recvTimeoutUsecs;
    private PannenkoekenWachtrijT m_pannenkoekenWachtrij;

scope nothrow @nogc:
    this(ushort port, PannenkoekenWachtrijT pannenkoekenWachtrij, long recvTimeoutUsecs = 2_000_000)
    {
        m_port = port;
        m_pannenkoekenWachtrij = pannenkoekenWachtrij;
        m_recvTimeoutUsecs = recvTimeoutUsecs;
    }

    @trusted
    void start()
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
            int listenResult = listen(m_listenSocket, /*backlog:*/ 0);
            assert(listenResult == 0);
        }

        log.info!"listening on port %hd"(m_port);

        while (true)
        {
            sockaddr_in sourceAddr;
            socklen_t sourceAddrSize = sourceAddr.sizeof;
            // log.info!"calling accept()";
            int socket = accept(m_listenSocket, cast(sockaddr*)&sourceAddr, &sourceAddrSize);
            // log.info!"incoming connection!";
            assert(socket >= 0);

            handleOurOnlyClient(socket);

            // log.info!"closing connection socket";
            shutdown(socket, 0);
            close(socket);
            // log.info!"socket closed";

            vTaskDelay(10);
        }
    }

    void handleOurOnlyClient(int socket)
    {
        log.info!"handleOurOnlyClient: Started";
        scope (exit)
            log.info!"handleOurOnlyClient: Exited";

        auto r = SocketReader!char(socket, m_recvTimeoutUsecs);

        @trusted
        void socketSend(C)(C[] data)
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
            log.warn!"handleOurOnlyClient: Client took too long to send";
            log.warn!"handleOurOnlyClient: Sending 408";
            socketSend(
                "HTTP/1.1 408 Request Timeout\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 19\r\n" ~
                    "\r\n" ~
                    "408 Request Timeout"
            );
        }

        auto firstLineBuf = UniqueHeapArray!char.create(64);
        char[] firstLine = r.readLine(firstLineBuf.get);

        if (r.timedOut)
        {
            send408;
            return;
        }
        else if (firstLine.startsWith("GET /hello HTTP"))
        {
            log.info!"handleOurOnlyClient: Handling GET /hello";
            socketSend(
                "HTTP/1.1 200 OK\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 6\r\n" ~
                    "\r\n" ~
                    "Hello!"
            );
        }
        else if (firstLine.startsWith("POST / HTTP"))
        {
            log.info!"handleOurOnlyClient: Handling POST /";

            int contentLength = -1;
            {
                auto headerLineBuf = UniqueHeapArray!char.create(256);
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
                            log.warn!"handleOurOnlyClient: Message too long, sending 400";
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
                log.warn!"handleOurOnlyClient: No Content-Length found, sending 400";
                socketSend("HTTP/1.1 400 Bad Request\r\n\r\n");
                return;
            }

            auto bodyBuf = UniqueHeapArray!char.create(1024);
            char[] body;
            while (body.length != contentLength) // contentLength is max 999
            {
                if (r.empty)
                {
                    log.warn!"handleOurOnlyClient: Body smaller than Content-Length, sending 400";
                    socketSend("HTTP/1.1 400 Bad Request\r\n\r\n");
                    return;
                }
                bodyBuf.get[body.length] = r.front;
                body = bodyBuf[0 .. body.length + 1];
                r.popFront;
            }

            bodyBuf[body.length] = 0;
            log.info!"handleOurOnlyClient: Got body %s"(&body[0]);

            auto entry = UniqueHeapArray!char.create(body.length);
            entry[] = body[];
            m_pannenkoekenWachtrij.addEntry(entry);

            socketSend("HTTP/1.1 204 No Content\r\n\r\n");
        }
        else
        {
            log.warn!"handleOurOnlyClient: Sending 404";
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

private
struct SocketReader(C = char) //
if (C.sizeof == 1)
{
    private int m_socket = -1;
    private long m_recvTimeoutUsecs;
    private bool m_isOpen = true;
    private bool m_timedOut;
    private bool m_calledEmpty;
    private UniqueHeapArray!C m_buf;
    private int m_received;
    private int m_currIndex;

scope nothrow @nogc:
    this(in int socket, in long recvTimeoutUsecs)
    {
        m_socket = socket;
        m_recvTimeoutUsecs = recvTimeoutUsecs;
        m_buf = typeof(m_buf).create(1024);
    }

    pure
    C front() const
    in (m_calledEmpty && m_isOpen)
        => m_buf.get[m_currIndex];

    pure
    void popFront()
    in (m_calledEmpty && m_isOpen)
    {
        m_currIndex++;
        m_calledEmpty = false;
    }

    @trusted
    bool empty()
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

    pure
    bool timedOut() const => m_timedOut;

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
