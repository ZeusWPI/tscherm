module app.pannenkoeken_wachtrij.pannenkoeken_wachtrij;

import app.pannenkoeken_wachtrij.http : HttpServer, Request, Response, Route;
import app.vga.color : Color;
import app.vga.font : Font;

import idf.freertos : pdPASS, TaskHandle_t, ulTaskGenericNotifyTake, vTaskDelay, vTaskSuspend, xTaskCreatePinnedToCore;

import idfd.log : Logger;

import ministd.traits : isInstanceOf;
import ministd.typecons : UniqueHeap, UniqueHeapArray;

@safe nothrow @nogc:

final
class PannenkoekenWachtrij(uint ct_width, uint ct_height, FontT) //
if (isInstanceOf!(Font, FontT))
{
    private enum log = Logger!"PannenkoekenWachtrij"();
    private enum Route ct_httpGetRoute = Route("GET", "/");
    private enum Route ct_httpPostRoute = Route("POST", "/");
    private enum Route[] ct_httpRoutes = [
        ct_httpGetRoute,
        ct_httpPostRoute,
    ];

    private const(FontT)* m_font;
    private UniqueHeapArray!(UniqueHeapArray!char) m_entries;
    private uint m_entryCount;

    private TaskHandle_t m_httpServerTask;
    private UniqueHeap!(HttpServer!ct_httpRoutes) m_httpServer;

nothrow @nogc:
    this(const(FontT)* font)
    {
        m_font = font;
        m_entries = typeof(m_entries).create(64);

        (() @trusted {
            // dfmt off
            auto result = xTaskCreatePinnedToCore(
                pvTaskCode: &httpServerTaskEntrypoint,
                pcName: "http",
                usStackDepth: 4000,
                pvParameters: cast(void*) this,
                uxPriority: 10,
                pvCreatedTask: &m_httpServerTask,
                xCoreID: 0,
            );
            assert(result == pdPASS);
            // dfmt on
        })();
    }

    private static @trusted extern (C)
    void httpServerTaskEntrypoint(void* thisPtr)
        => (cast(typeof(this)) thisPtr).httpServerTask;

    private
    void httpServerTask()
    {
        m_httpServer = typeof(m_httpServer).create(cast(ushort) 80);
        m_httpServer.setRouteHandler!ct_httpGetRoute(&onGet);
        m_httpServer.setRouteHandler!ct_httpPostRoute(&onPost);
        m_httpServer.start;
    }

    void onGet(ref Request req, ref Response res)
    {
    }

    void onPost(ref Request req, ref Response res)
    {
        addEntry(UniqueHeapArray!char(req.body));
    }

    int addEntry(UniqueHeapArray!char name)
    {
        if (m_entryCount >= m_entries.length)
            return -1;

        m_entries[m_entryCount] = name;
        m_entryCount++;
        return m_entryCount;
    }

    void drawLine(Color[] buf, const uint y) const
    {
        if (m_entryCount)
            drawLineEntries(buf, y);
        else
            drawLineNoEntries(buf, y);
    }

    private
    void drawLineNoEntries(Color[] buf, const uint y) const
    {
        enum uint ct_glyphWidth = FontT.ct_glyphWidth;
        enum uint ct_glyphHeight = FontT.ct_glyphHeight;
        enum Color ct_backgroundColor = Color.BLACK;
        enum string ct_text = "De pannenkoekenwachtrij is leeg";
        static assert(ct_text.length * ct_glyphWidth <= ct_width);

        enum uint yTextStart = (ct_height - ct_glyphHeight) / 2;
        enum uint yTextEnd = yTextStart + ct_glyphHeight;
        enum uint xTextStart = (ct_width - ct_glyphWidth * ct_text.length) / 2;
        enum uint xTextEnd = xTextStart + ct_glyphWidth * ct_text.length;

        if (yTextStart <= y && y < yTextEnd)
        {
            uint glyphY = y - yTextStart;
            buf[0 .. xTextStart] = ct_backgroundColor;
            m_font.drawTextLine(buf[xTextStart .. xTextEnd], glyphY, ct_text);
            buf[xTextEnd .. ct_width] = ct_backgroundColor;
        }
        else
        {
            buf[] = Color.BLACK;
        }
    }

    private
    void drawLineEntries(Color[] buf, const uint y) const
    {
        enum uint ct_glyphHeight = FontT.ct_glyphHeight;
        enum uint ct_padding = 2;
        enum uint ct_margin = 2;
        enum Color ct_paddingColor = Color.BLACK;
        enum Color ct_marginColor = Color(Color.WHITE / 4);

        enum uint topMarginBegin = 0;
        enum uint topMarginEnd = topMarginBegin + ct_margin;
        enum uint topPaddingBegin = topMarginEnd;
        enum uint topPaddingEnd = topPaddingBegin + ct_padding;
        enum uint textBegin = topPaddingEnd;
        enum uint textEnd = textBegin + ct_glyphHeight;
        enum uint bottomPaddingBegin = textEnd;
        enum uint bottomPaddingEnd = bottomPaddingBegin + ct_padding;
        enum uint bottomMarginBegin = bottomPaddingEnd;
        enum uint bottomMarginEnd = bottomMarginBegin + ct_margin;

        enum uint ct_sectionHeight = bottomMarginEnd;

        uint section = y / ct_sectionHeight;
        uint sectionLine = y % ct_sectionHeight;

        if (section >= m_entryCount)
        {
            buf[] = Color.BLACK;
            return;
        }

        if (sectionLine < topMarginEnd)
        {
            buf[] = ct_marginColor;
        }
        else if (sectionLine < topPaddingEnd)
        {
            buf[] = ct_paddingColor;
        }
        else if (sectionLine < textEnd)
        {
            uint glyphY = sectionLine - textBegin;

            const(char)[] text = m_entries[section];
            m_font.drawTextLine(buf, glyphY, text);
        }
        else if (sectionLine < bottomPaddingEnd)
        {
            buf[] = ct_paddingColor;
        }
        else if (sectionLine < bottomMarginEnd)
        {
            buf[] = ct_marginColor;
        }
        else
        {
            assert(false);
        }
    }
}
