module idfd.net.wifi_client;

import idfd.log : Logger;
import idfd.nvs_flash : initNvsFlash, nvsFlashInitialized;

import idf.esp_common.esp_err : ESP_ERROR_CHECK;
import idf.esp_event : esp_event_base_t, esp_event_handler_instance_t, ESP_EVENT_ANY_ID,
    esp_event_loop_create_default, esp_event_handler_instance_register;
import idf.freertos : EventGroupHandle_t,
    pdFALSE, portMAX_DELAY,
    xEventGroupCreate, xEventGroupSetBits, xEventGroupWaitBits;
import idf.esp_netif : esp_netif_init, IP_EVENT, ip_event_got_ip_t, ip_event_t;
import idf.esp_wifi : esp_netif_create_default_wifi_sta, esp_wifi_connect, esp_wifi_init,
    esp_wifi_set_config, esp_wifi_set_mode, esp_wifi_start, wifi_auth_mode_t,
    wifi_config_t, WIFI_EVENT, wifi_event_t, WIFI_INIT_CONFIG_DEFAULT, wifi_init_config_t,
    wifi_interface_t, wifi_mode_t, wifi_sta_config_t;

import ministd.string : setStringz;

@safe:

struct WiFiClient
{
    private enum log = Logger!"WifiClient"();

    private
    enum EventGroupBits : uint
    {
        CONNECTED = 1 << 0,
    }

    private string m_ssid, m_password;
    private EventGroupHandle_t m_eventGroup;

scope:
    this(string ssid, string password = "")
    in (ssid.length && ssid.length <= wifi_sta_config_t.ssid.length)
    in (password.length <= wifi_sta_config_t.password.length)
    {
        m_ssid = ssid;
        m_password = password;
    }

    private static @trusted nothrow @nogc extern (C)
    void wifiEventHandler(
        void* wifiClientVoidPtr,
        esp_event_base_t eventBase, int eventId,
        void* eventData,
    )
    in (wifiClientVoidPtr !is null)
    {
        typeof(this)* wifiClient = cast(typeof(this)*) wifiClientVoidPtr;
        wifiClient.handleEvent(eventBase, eventId, eventData);
    }

    @trusted
    void startAsync()
    {
        if (!nvsFlashInitialized)
            initNvsFlash!true;

        m_eventGroup = xEventGroupCreate;

        ESP_ERROR_CHECK(esp_netif_init);

        ESP_ERROR_CHECK(esp_event_loop_create_default);
        esp_netif_create_default_wifi_sta;

        wifi_init_config_t initCfg = WIFI_INIT_CONFIG_DEFAULT;
        log.info!"tx: %d"(initCfg.dynamic_tx_buf_num);
        ESP_ERROR_CHECK(esp_wifi_init(&initCfg));

        esp_event_handler_instance_t instance_any_id;
        esp_event_handler_instance_t instance_got_ip;
        // dfmt off
        ESP_ERROR_CHECK(esp_event_handler_instance_register(
            WIFI_EVENT, ESP_EVENT_ANY_ID, &wifiEventHandler, &this, &instance_any_id
        ));
        ESP_ERROR_CHECK(esp_event_handler_instance_register(
            IP_EVENT, ip_event_t.IP_EVENT_STA_GOT_IP, &wifiEventHandler, &this, &instance_got_ip
        ));
        // dfmt on

        wifi_config_t wifi_config;

        wifi_config.sta.ssid[].setStringz(m_ssid);
        wifi_config.sta.password[].setStringz(m_password);
        // Set minimum accepted network security
        wifi_config.sta.threshold.authmode = m_password.length
            ? wifi_auth_mode_t.WIFI_AUTH_WEP : wifi_auth_mode_t.WIFI_AUTH_OPEN;

        ESP_ERROR_CHECK(esp_wifi_set_mode(wifi_mode_t.WIFI_MODE_STA));
        ESP_ERROR_CHECK(esp_wifi_set_config(wifi_interface_t.WIFI_IF_STA, &wifi_config));
        ESP_ERROR_CHECK(esp_wifi_start);
    }

    @trusted
    void waitForConnection()
    {
        xEventGroupWaitBits(m_eventGroup, EventGroupBits.CONNECTED, pdFALSE, pdFALSE, portMAX_DELAY);
    }

    private @trusted nothrow @nogc
    void handleEvent(esp_event_base_t eventBase, int eventId, void* eventData)
    {
        if (eventBase == WIFI_EVENT)
        {
            if (eventId == wifi_event_t.WIFI_EVENT_STA_START)
            {
                log.info!"Connecting to AP...";
                esp_wifi_connect;
            }
            else if (eventId == wifi_event_t.WIFI_EVENT_STA_DISCONNECTED)
            {
                log.warn!"Failed to connect to AP, retrying...";
                esp_wifi_connect;
            }
        }
        else if (eventBase == IP_EVENT)
        {
            if (eventId == ip_event_t.IP_EVENT_STA_GOT_IP)
            {
                ip_event_got_ip_t* event = cast(ip_event_got_ip_t*) eventData;
                uint* ipPtr = &event.ip_info.ip.addr;
                ubyte[] b = (cast(ubyte*) ipPtr)[0 .. 4];
                log.info!"Connected with ip address: %d.%d.%d.%d"(b[0], b[1], b[2], b[3]);

                // Notify waitForConnection via event group
                xEventGroupSetBits(m_eventGroup, EventGroupBits.CONNECTED);
            }
        }
    }
}
