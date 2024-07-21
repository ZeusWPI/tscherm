module idf.esp_wifi.macro_impl;

import idf.esp_event : esp_event_send_internal;
import idf.esp_wifi.esp_private.wifi_os_adapter : g_wifi_osi_funcs;
import idf.esp_wifi.esp_wifi;
import idf.sdkconfig;

@safe nothrow @nogc:
// dfmt off

@trusted
wifi_init_config_t WIFI_INIT_CONFIG_DEFAULT()
{
    return wifi_init_config_t(
        event_handler : &esp_event_send_internal,
        osi_funcs : &g_wifi_osi_funcs,
        wpa_crypto_funcs : g_wifi_default_wpa_crypto_funcs,
        static_rx_buf_num : CONFIG_ESP32_WIFI_STATIC_RX_BUFFER_NUM,
        dynamic_rx_buf_num : CONFIG_ESP32_WIFI_DYNAMIC_RX_BUFFER_NUM,
        tx_buf_type : CONFIG_ESP32_WIFI_TX_BUFFER_TYPE,
        static_tx_buf_num : WIFI_STATIC_TX_BUFFER_NUM,
        dynamic_tx_buf_num : WIFI_DYNAMIC_TX_BUFFER_NUM,
        rx_mgmt_buf_type : CONFIG_ESP_WIFI_DYNAMIC_RX_MGMT_BUF,
        rx_mgmt_buf_num : WIFI_RX_MGMT_BUF_NUM_DEF,
        cache_tx_buf_num : WIFI_CACHE_TX_BUFFER_NUM,
        csi_enable : WIFI_CSI_ENABLED,
        ampdu_rx_enable : WIFI_AMPDU_RX_ENABLED,
        ampdu_tx_enable : WIFI_AMPDU_TX_ENABLED,
        amsdu_tx_enable : WIFI_AMSDU_TX_ENABLED,
        nvs_enable : WIFI_NVS_ENABLED,
        nano_enable : WIFI_NANO_FORMAT_ENABLED,
        rx_ba_win : WIFI_DEFAULT_RX_BA_WIN,
        wifi_task_core_id : WIFI_TASK_CORE_ID,
        beacon_max_len : WIFI_SOFTAP_BEACON_MAX_LEN,
        mgmt_sbuf_num : WIFI_MGMT_SBUF_NUM,
        feature_caps : g_wifi_feature_caps,
        sta_disconnected_pm : WIFI_STA_DISCONNECTED_PM_ENABLED,
        espnow_max_encrypt_num : CONFIG_ESP_WIFI_ESPNOW_MAX_ENCRYPT_NUM,
        magic : WIFI_INIT_CONFIG_MAGIC,
    );
}
