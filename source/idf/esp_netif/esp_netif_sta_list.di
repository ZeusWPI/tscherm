module idf.esp_netif.esp_netif_sta_list;

import idf.esp_common.esp_err : esp_err_t;
import idf.esp_netif.esp_netif_ip_addr : esp_ip4_addr_t;
import idf.esp_wifi.esp_wifi_types : ESP_WIFI_MAX_CONN_NUM, wifi_sta_list_t;

@safe nothrow @nogc extern (C):

// TODO

// dfmt off
/**
 * @brief station list info element
 */
struct esp_netif_sta_info_t
{
    ubyte[6] mac;       /**< Station MAC address */
    esp_ip4_addr_t ip;  /**< Station assigned IP address */
}

/**
 * @brief station list structure
 */
struct esp_netif_sta_list_t
{
    esp_netif_sta_info_t[ESP_WIFI_MAX_CONN_NUM] sta; /**< Connected stations */
    int num;                                         /**< Number of connected stations */
}
// dfmt on

//
// Group: ESP_NETIF_STA_LIST
//

/**
 * @brief  Get IP information for stations connected to the Wi-Fi AP interface
 *
 * @param[in]   wifi_sta_list Wi-Fi station info list, returned from esp_wifi_ap_get_sta_list()
 * @param[out]  netif_sta_list IP layer station info list, corresponding to MAC addresses provided in wifi_sta_list
 *
 * @return
 *         - ESP_OK
 *         - ESP_ERR_ESP_NETIF_NO_MEM
 *         - ESP_ERR_ESP_NETIF_INVALID_PARAMS
 */
esp_err_t esp_netif_get_sta_list(const wifi_sta_list_t* wifi_sta_list, esp_netif_sta_list_t* netif_sta_list);
