module idf.esp_wifi.esp_wifi;

import idf.esp_common.esp_err : esp_err_t, ESP_ERR_WIFI_BASE;
import idf.esp_event : system_event_handler_t;
import idf.esp_wifi.esp_private.wifi_os_adapter : wifi_osi_funcs_t;
import idf.esp_wifi.esp_wifi_crypto_types : wpa_crypto_funcs_t;
import idf.esp_wifi.esp_wifi_types;
import idf.sdkconfig;

@safe nothrow @nogc extern (C):

// dfmt off
enum ESP_ERR_WIFI_NOT_INIT        = ESP_ERR_WIFI_BASE + 1;   /*!< WiFi driver was not installed by esp_wifi_init */
enum ESP_ERR_WIFI_NOT_STARTED     = ESP_ERR_WIFI_BASE + 2;   /*!< WiFi driver was not started by esp_wifi_start */
enum ESP_ERR_WIFI_NOT_STOPPED     = ESP_ERR_WIFI_BASE + 3;   /*!< WiFi driver was not stopped by esp_wifi_stop */
enum ESP_ERR_WIFI_IF              = ESP_ERR_WIFI_BASE + 4;   /*!< WiFi interface error */
enum ESP_ERR_WIFI_MODE            = ESP_ERR_WIFI_BASE + 5;   /*!< WiFi mode error */
enum ESP_ERR_WIFI_STATE           = ESP_ERR_WIFI_BASE + 6;   /*!< WiFi internal state error */
enum ESP_ERR_WIFI_CONN            = ESP_ERR_WIFI_BASE + 7;   /*!< WiFi internal control block of station or soft-AP error */
enum ESP_ERR_WIFI_NVS             = ESP_ERR_WIFI_BASE + 8;   /*!< WiFi internal NVS module error */
enum ESP_ERR_WIFI_MAC             = ESP_ERR_WIFI_BASE + 9;   /*!< MAC address is invalid */
enum ESP_ERR_WIFI_SSID            = ESP_ERR_WIFI_BASE + 10;  /*!< SSID is invalid */
enum ESP_ERR_WIFI_PASSWORD        = ESP_ERR_WIFI_BASE + 11;  /*!< Password is invalid */
enum ESP_ERR_WIFI_TIMEOUT         = ESP_ERR_WIFI_BASE + 12;  /*!< Timeout error */
enum ESP_ERR_WIFI_WAKE_FAIL       = ESP_ERR_WIFI_BASE + 13;  /*!< WiFi is in sleep state(RF closed) and wakeup fail */
enum ESP_ERR_WIFI_WOULD_BLOCK     = ESP_ERR_WIFI_BASE + 14;  /*!< The caller would block */
enum ESP_ERR_WIFI_NOT_CONNECT     = ESP_ERR_WIFI_BASE + 15;  /*!< Station still in disconnect status */
enum ESP_ERR_WIFI_POST            = ESP_ERR_WIFI_BASE + 18;  /*!< Failed to post the event to WiFi task */
enum ESP_ERR_WIFI_INIT_STATE      = ESP_ERR_WIFI_BASE + 19;  /*!< Invalid WiFi state when init/deinit is called */
enum ESP_ERR_WIFI_STOP_STATE      = ESP_ERR_WIFI_BASE + 20;  /*!< Returned when WiFi is stopping */
enum ESP_ERR_WIFI_NOT_ASSOC       = ESP_ERR_WIFI_BASE + 21;  /*!< The WiFi connection is not associated */
enum ESP_ERR_WIFI_TX_DISALLOW     = ESP_ERR_WIFI_BASE + 22;  /*!< The WiFi TX is disallowed */
enum ESP_ERR_WIFI_DISCARD         = ESP_ERR_WIFI_BASE + 23;  /*!< Discard frame */
enum ESP_ERR_WIFI_ROC_IN_PROGRESS = ESP_ERR_WIFI_BASE + 28;  /*!< ROC op is in progress */
// dfmt on

static if (is(typeof(CONFIG_ESP32_WIFI_STATIC_TX_BUFFER_NUM)))
    enum WIFI_STATIC_TX_BUFFER_NUM = CONFIG_ESP32_WIFI_STATIC_TX_BUFFER_NUM;
else
    enum WIFI_STATIC_TX_BUFFER_NUM = 0;

static if (is(typeof(CONFIG_ESP32_SPIRAM_SUPPORT)) || is(typeof(CONFIG_ESP32S2_SPIRAM_SUPPORT)) || is(
        CONFIG_ESP32S3_SPIRAM_SUPPORT))
    enum WIFI_CACHE_TX_BUFFER_NUM = CONFIG_ESP32_WIFI_CACHE_TX_BUFFER_NUM;
else
    enum WIFI_CACHE_TX_BUFFER_NUM = 0;

static if (is(typeof(CONFIG_ESP32_WIFI_DYNAMIC_TX_BUFFER_NUM)))
    enum WIFI_DYNAMIC_TX_BUFFER_NUM = CONFIG_ESP32_WIFI_DYNAMIC_TX_BUFFER_NUM;
else
    enum WIFI_DYNAMIC_TX_BUFFER_NUM = 0;

static if (is(typeof(CONFIG_ESP_WIFI_RX_MGMT_BUF_NUM_DEF)))
    enum WIFI_RX_MGMT_BUF_NUM_DEF = CONFIG_ESP_WIFI_RX_MGMT_BUF_NUM_DEF;
else
    enum WIFI_RX_MGMT_BUF_NUM_DEF = 0;

enum WIFI_CSI_ENABLED = is(typeof(CONFIG_ESP32_WIFI_CSI_ENABLED));
enum WIFI_AMPDU_RX_ENABLED = is(typeof(CONFIG_ESP32_WIFI_AMPDU_RX_ENABLED));
enum WIFI_AMPDU_TX_ENABLED = is(typeof(CONFIG_ESP32_WIFI_AMPDU_TX_ENABLED));
enum WIFI_AMSDU_TX_ENABLED = is(typeof(CONFIG_ESP32_WIFI_AMSDU_TX_ENABLED));
enum WIFI_NVS_ENABLED = is(typeof(CONFIG_ESP32_WIFI_NVS_ENABLED));
enum WIFI_NANO_FORMAT_ENABLED = is(typeof(CONFIG_NEWLIB_NANO_FORMAT));

enum WIFI_INIT_CONFIG_MAGIC = 0x1F2F3F4F;

static if (is(typeof(CONFIG_ESP32_WIFI_AMPDU_RX_ENABLED)))
    enum WIFI_DEFAULT_RX_BA_WIN = CONFIG_ESP32_WIFI_RX_BA_WIN;
else
    enum WIFI_DEFAULT_RX_BA_WIN = 0;

enum WIFI_TASK_CORE_ID = is(typeof(CONFIG_ESP32_WIFI_TASK_PINNED_TO_CORE_1));

static if (is(typeof(CONFIG_ESP32_WIFI_SOFTAP_BEACON_MAX_LEN)))
    enum WIFI_SOFTAP_BEACON_MAX_LEN = CONFIG_ESP32_WIFI_SOFTAP_BEACON_MAX_LEN;
else
    enum WIFI_SOFTAP_BEACON_MAX_LEN = 752;

static if (is(typeof(CONFIG_ESP32_WIFI_MGMT_SBUF_NUM)))
    enum WIFI_MGMT_SBUF_NUM = CONFIG_ESP32_WIFI_MGMT_SBUF_NUM;
else
    enum WIFI_MGMT_SBUF_NUM = 32;

enum WIFI_STA_DISCONNECTED_PM_ENABLED = is(typeof(CONFIG_ESP_WIFI_STA_DISCONNECTED_PM_ENABLE));

enum CONFIG_FEATURE_WPA3_SAE_BIT = 1 << 0;
enum CONFIG_FEATURE_CACHE_TX_BUF_BIT = 1 << 1;
enum CONFIG_FEATURE_FTM_INITIATOR_BIT = 1 << 2;
enum CONFIG_FEATURE_FTM_RESPONDER_BIT = 1 << 3;

// dfmt off
/// WiFi stack configuration parameters passed to esp_wifi_init call.
struct wifi_init_config_t
{
    system_event_handler_t event_handler;          /**< WiFi event handler */
    wifi_osi_funcs_t*      osi_funcs;              /**< WiFi OS functions */
    wpa_crypto_funcs_t     wpa_crypto_funcs;       /**< WiFi station crypto functions when connect */
    int                    static_rx_buf_num;      /**< WiFi static RX buffer number */
    int                    dynamic_rx_buf_num;     /**< WiFi dynamic RX buffer number */
    int                    tx_buf_type;            /**< WiFi TX buffer type */
    int                    static_tx_buf_num;      /**< WiFi static TX buffer number */
    int                    dynamic_tx_buf_num;     /**< WiFi dynamic TX buffer number */
    int                    rx_mgmt_buf_type;       /**< WiFi RX MGMT buffer type */
    int                    rx_mgmt_buf_num;        /**< WiFi RX MGMT buffer number */
    int                    cache_tx_buf_num;       /**< WiFi TX cache buffer number */
    int                    csi_enable;             /**< WiFi channel state information enable flag */
    int                    ampdu_rx_enable;        /**< WiFi AMPDU RX feature enable flag */
    int                    ampdu_tx_enable;        /**< WiFi AMPDU TX feature enable flag */
    int                    amsdu_tx_enable;        /**< WiFi AMSDU TX feature enable flag */
    int                    nvs_enable;             /**< WiFi NVS flash enable flag */
    int                    nano_enable;            /**< Nano option for printf/scan family enable flag */
    int                    rx_ba_win;              /**< WiFi Block Ack RX window size */
    int                    wifi_task_core_id;      /**< WiFi Task Core ID */
    int                    beacon_max_len;         /**< WiFi softAP maximum length of the beacon */
    int                    mgmt_sbuf_num;          /**< WiFi management short buffer number, the minimum value is 6, the maximum value is 32 */
    ulong                  feature_caps;           /**< Enables additional WiFi features and capabilities */
    bool                   sta_disconnected_pm;    /**< WiFi Power Management for station at disconnected status */
    int                    espnow_max_encrypt_num; /**< Maximum encrypt number of peers supported by espnow */
    int                    magic;                  /**< WiFi init magic number, it should be the last field */
}
// dfmt on

alias wifi_promiscuous_cb_t = void function(void* buf, wifi_promiscuous_pkt_type_t type);
alias esp_vendor_ie_cb_t = void function(void* ctx, wifi_vendor_ie_type_t type, const ubyte[6] sa, const vendor_ie_data_t* vnd_ie, int rssi);
alias wifi_csi_cb_t = void function(void* ctx, wifi_csi_info_t* data);

extern __gshared const wpa_crypto_funcs_t g_wifi_default_wpa_crypto_funcs;
extern __gshared ulong g_wifi_feature_caps;

esp_err_t esp_wifi_init(const wifi_init_config_t* config);
esp_err_t esp_wifi_deinit();
esp_err_t esp_wifi_set_mode(wifi_mode_t mode);
esp_err_t esp_wifi_get_mode(wifi_mode_t* mode);
esp_err_t esp_wifi_start();
esp_err_t esp_wifi_stop();
esp_err_t esp_wifi_restore();
esp_err_t esp_wifi_connect();
esp_err_t esp_wifi_disconnect();
esp_err_t esp_wifi_clear_fast_connect();
esp_err_t esp_wifi_deauth_sta(ushort aid);
esp_err_t esp_wifi_scan_start(const wifi_scan_config_t* config, bool block);
esp_err_t esp_wifi_scan_stop();
esp_err_t esp_wifi_scan_get_ap_num(ushort* number);
esp_err_t esp_wifi_scan_get_ap_records(ushort* number, wifi_ap_record_t* ap_records);
esp_err_t esp_wifi_clear_ap_list();
esp_err_t esp_wifi_sta_get_ap_info(wifi_ap_record_t* ap_info);
esp_err_t esp_wifi_set_ps(wifi_ps_type_t type);
esp_err_t esp_wifi_get_ps(wifi_ps_type_t* type);
esp_err_t esp_wifi_set_protocol(wifi_interface_t ifx, ubyte protocol_bitmap);
esp_err_t esp_wifi_get_protocol(wifi_interface_t ifx, ubyte* protocol_bitmap);
esp_err_t esp_wifi_set_bandwidth(wifi_interface_t ifx, wifi_bandwidth_t bw);
esp_err_t esp_wifi_get_bandwidth(wifi_interface_t ifx, wifi_bandwidth_t* bw);
esp_err_t esp_wifi_set_channel(ubyte primary, wifi_second_chan_t second);
esp_err_t esp_wifi_get_channel(ubyte* primary, wifi_second_chan_t* second);
esp_err_t esp_wifi_set_country(const wifi_country_t* country);
esp_err_t esp_wifi_get_country(wifi_country_t* country);
esp_err_t esp_wifi_set_mac(wifi_interface_t ifx, const ubyte[6] mac);
esp_err_t esp_wifi_get_mac(wifi_interface_t ifx, ubyte[6] mac);
esp_err_t esp_wifi_set_promiscuous_rx_cb(wifi_promiscuous_cb_t cb);
esp_err_t esp_wifi_set_promiscuous(bool en);
esp_err_t esp_wifi_get_promiscuous(bool* en);
esp_err_t esp_wifi_set_promiscuous_filter(const wifi_promiscuous_filter_t* filter);
esp_err_t esp_wifi_get_promiscuous_filter(wifi_promiscuous_filter_t* filter);
esp_err_t esp_wifi_set_promiscuous_ctrl_filter(const wifi_promiscuous_filter_t* filter);
esp_err_t esp_wifi_get_promiscuous_ctrl_filter(wifi_promiscuous_filter_t* filter);
esp_err_t esp_wifi_set_config(wifi_interface_t interface_, wifi_config_t* conf);
esp_err_t esp_wifi_get_config(wifi_interface_t interface_, wifi_config_t* conf);
esp_err_t esp_wifi_ap_get_sta_list(wifi_sta_list_t* sta);
esp_err_t esp_wifi_ap_get_sta_aid(const ubyte[6] mac, ushort* aid);
esp_err_t esp_wifi_set_storage(wifi_storage_t storage);
esp_err_t esp_wifi_set_vendor_ie(bool enable, wifi_vendor_ie_type_t type, wifi_vendor_ie_id_t idx, const void* vnd_ie);
esp_err_t esp_wifi_set_vendor_ie_cb(esp_vendor_ie_cb_t cb, void* ctx);
esp_err_t esp_wifi_set_max_tx_power(byte power);
esp_err_t esp_wifi_get_max_tx_power(byte* power);
esp_err_t esp_wifi_set_event_mask(uint mask);
esp_err_t esp_wifi_get_event_mask(uint* mask);
esp_err_t esp_wifi_80211_tx(wifi_interface_t ifx, const void* buffer, int len, bool en_sys_seq);
esp_err_t esp_wifi_set_csi_rx_cb(wifi_csi_cb_t cb, void* ctx);
esp_err_t esp_wifi_set_csi_config(const wifi_csi_config_t* config);
esp_err_t esp_wifi_set_csi(bool en);
esp_err_t esp_wifi_set_ant_gpio(const wifi_ant_gpio_config_t* config);
esp_err_t esp_wifi_get_ant_gpio(wifi_ant_gpio_config_t* config);
esp_err_t esp_wifi_set_ant(const wifi_ant_config_t* config);
esp_err_t esp_wifi_get_ant(wifi_ant_config_t* config);
long esp_wifi_get_tsf_time(wifi_interface_t interface_);
esp_err_t esp_wifi_set_inactive_time(wifi_interface_t ifx, ushort sec);
esp_err_t esp_wifi_get_inactive_time(wifi_interface_t ifx, ushort* sec);
esp_err_t esp_wifi_statis_dump(uint modules);
esp_err_t esp_wifi_set_rssi_threshold(int rssi);
esp_err_t esp_wifi_ftm_initiate_session(wifi_ftm_initiator_cfg_t* cfg);
esp_err_t esp_wifi_ftm_end_session();
esp_err_t esp_wifi_ftm_resp_set_offset(short offset_cm);
esp_err_t esp_wifi_ftm_get_report(wifi_ftm_report_entry_t* report, ubyte num_entries);
esp_err_t esp_wifi_config_11b_rate(wifi_interface_t ifx, bool disable);
esp_err_t esp_wifi_set_connectionless_wake_interval(ushort interval);
esp_err_t esp_wifi_force_wakeup_acquire();
esp_err_t esp_wifi_force_wakeup_release();
esp_err_t esp_wifi_set_country_code(const char* country, bool ieee80211d_enabled);
esp_err_t esp_wifi_get_country_code(char* country);
esp_err_t esp_wifi_config_80211_tx_rate(wifi_interface_t ifx, wifi_phy_rate_t rate);
esp_err_t esp_wifi_disable_pmf_config(wifi_interface_t ifx);
esp_err_t esp_wifi_sta_get_aid(ushort* aid);
esp_err_t esp_wifi_sta_get_negotiated_phymode(wifi_phy_mode_t* phymode);
esp_err_t esp_wifi_sta_get_rssi(int* rssi);
