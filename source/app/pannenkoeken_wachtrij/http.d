module app.pannenkoeken_wachtrij.http;

import idf.errno : EAGAIN, errno;
import idf.esp_timer : esp_timer_get_time;
import idf.freertos : vTaskDelay;
import idf.stdlib : atoi;
import idf.sys.socket : accept, AF_INET, bind, close, connect, htonl, htons, IPADDR_ANY, IPPROTO_IP, listen,
    MSG_DONTWAIT, recv, send, shutdown, SOCK_STREAM, sockaddr, sockaddr_in, socket, socklen_t;

import idfd.log : Logger;

import ministd.conv : to;
import ministd.string : startsWith;
import ministd.typecons : UniqueHeapArray;

@safe nothrow @nogc:

struct Route
{
    string method;
    string path;
}

struct Request
{
    UniqueHeapArray!char body;
}

struct Response
{
    uint status;
    string body;
}

alias RouteHandler = void delegate(ref Request req, ref Response res) @safe nothrow @nogc;

class HttpServer(Route[] ct_routes) //
{
    private enum log = Logger!"HttpServer"();

    private enum size_t routeIndex(Route ct_route) = () {
        static foreach (i, el; ct_routes)
            static if (ct_route == el)
                enum idx = i;
        static assert(is(typeof(idx)), "routeIndex: no such route");
        return idx;
    }();

    private ushort m_port;
    private long m_recvTimeoutUsecs;
    private RouteHandler[ct_routes.length] m_routeHandlers;
    private int m_listenSocket;

scope nothrow @nogc:
    this(ushort port, long recvTimeoutUsecs = 2_000_000)
    {
        m_port = port;
        m_recvTimeoutUsecs = recvTimeoutUsecs;
    }

    void setRouteHandler(Route ct_route)(RouteHandler routeHandler)
    {
        m_routeHandlers[routeIndex!ct_route] = routeHandler;
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
            int socket = accept(m_listenSocket, cast(sockaddr*)&sourceAddr, &sourceAddrSize);
            assert(socket >= 0);

            handleIncomingConnection(socket);

            shutdown(socket, 0);
            close(socket);

            vTaskDelay(10);
        }
    }

    void handleIncomingConnection(int socket)
    {
        auto socketReader = SocketReader!char(socket, m_recvTimeoutUsecs);

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

        void send400()
        {
            socketSend("HTTP/1.1 400 Bad Request\r\n\r\n");
        }

        void send404()
        {
            socketSend(
                "HTTP/1.1 404 Not Found\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 13\r\n" ~
                    "\r\n" ~
                    "404 Not Found"
            );
        }

        void send408()
        {
            socketSend(
                "HTTP/1.1 408 Request Timeout\r\n" ~
                    "Content-Type: text/plain\r\n" ~
                    "Content-Length: 19\r\n" ~
                    "\r\n" ~
                    "408 Request Timeout"
            );
        }

        RouteHandler routeHandler;
        {
            auto firstLineBuf = UniqueHeapArray!char.create(64);
            char[] firstLine = socketReader.readLine(firstLineBuf.get);
            if (socketReader.timedOut)
            {
                send408;
                return;
            }

            // dfmt off
            bool foundRoute;
            size_t routeIdx;
            static foreach (i, enum Route route; ct_routes)
            {{
                enum string routeFirstLine = route.method ~ " " ~ route.path ~ " HTTP";
                if (!foundRoute && firstLine.startsWith(routeFirstLine))
                {
                    foundRoute = true;
                    routeIdx = i;
                }
            }}
            // dfmt on
            if (!foundRoute)
            {
                send404;
                return;
            }

            routeHandler = m_routeHandlers[routeIdx];
            if (routeHandler is null)
            {
                send404;
                return;
            }
        }

        int contentLength = -1;
        {
            auto headerLineBuf = UniqueHeapArray!char.create(256);
            while (true)
            {
                char[] line = socketReader.readLine(headerLineBuf.get);
                if (line.length == 0)
                {
                    // Connection closed
                    if (socketReader.timedOut)
                        send408; // Closed by us
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
                        // Content-Length too large
                        send400;
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

        UniqueHeapArray!char body;
        if (contentLength > 0)
        {
            UniqueHeapArray!char bodyBuf = UniqueHeapArray!char.create(1024);
            char[] bodyBufView;
            while (bodyBufView.length != contentLength) // contentLength is max 999
            {
                if (socketReader.empty)
                {
                    // Body smaller than Content-Length
                    send400;
                    return;
                }
                bodyBuf.get[bodyBufView.length] = socketReader.front;
                bodyBufView = bodyBuf[0 .. bodyBufView.length + 1];
                socketReader.popFront;
            }
            body = UniqueHeapArray!char.create(bodyBufView.length);
            body[] = bodyBufView[];
        }

        Request req = Request(body);
        Response res = Response();

        routeHandler(req, res);

        if (!res.status)
            res.status = res.body.length ? 200 : 204;
        socketSend("HTTP/1.1 ");
        socketSend(res.status.to!(char[]));
        socketSend("\r\n");
        if (res.body.length)
        {
            socketSend("Content-Length: ");
            socketSend(res.body.length.to!(char[]));
            socketSend("\r\n");
            socketSend("Content-Type: text/html\r\n");
        }
        socketSend("\r\n");
        if (res.body.length)
        {
            socketSend(res.body);
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
