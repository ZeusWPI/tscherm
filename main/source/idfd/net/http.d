module idfd.net.http;

import idf.stdio : printf;
import idf.esp_common.esp_err : ESP_ERROR_CHECK;

@safe:

struct HttpServer
{
    private httpd_handle_t m_server;
    private httpd_config_t m_config;

    this(in ushort port)
    {
        m_server = null;
        m_config = HTTPD_DEFAULT_CONFIG();
        m_config.lru_purge_enable = true;
        m_config.global_user_ctx = &this;
        m_config.uri_match_fn = &httpd_uri_match_wildcard;
        m_config.server_port = port;
    }

    void start()
    {
        printf("HttpServer: Starting on port %d", m_config.server_port);
        ESP_ERROR_CHECK(httpd_start(&m_server, &m_config));

        httpd_uri_t[] handlers = [
            {method: HTTP_GET, uri: "/hello", handler: &handleGetHello},
        ];
        foreach (ref handler; handlers)
            httpd_register_uri_handler(server, &handler);
    }

    static esp_err_t handleGetHello(httpd_req_t* req)
    {
        HttpServer* instance = cast(HttpServer*) httpd_get_global_user_ctx(req.handle);

        const char* responseString = "Hello World";
        httpd_resp_send(req, responseString, HTTPD_RESP_USE_STRLEN);

        return ESP_OK;
    }
}