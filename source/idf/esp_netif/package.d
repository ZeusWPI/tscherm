module idf.esp_netif;

import idf.esp_common.esp_err : esp_err_t;
import idf.esp_event : esp_event_base_t;

@safe nothrow @nogc extern (C):
// dfmt off

alias esp_netif_t = void;

/** IP event declarations */
enum ip_event_t
{
    IP_EVENT_STA_GOT_IP,       /*!< station got IP from connected AP */
    IP_EVENT_STA_LOST_IP,      /*!< station lost IP and the IP is reset to 0 */
    IP_EVENT_AP_STAIPASSIGNED, /*!< soft-AP assign an IP to a connected station */
    IP_EVENT_GOT_IP6,          /*!< station or ap or ethernet interface v6IP addr is preferred */
    IP_EVENT_ETH_GOT_IP,       /*!< ethernet got IP from connected AP */
    IP_EVENT_ETH_LOST_IP,      /*!< ethernet lost IP and the IP is reset to 0 */
    IP_EVENT_PPP_GOT_IP,       /*!< PPP interface got IP */
    IP_EVENT_PPP_LOST_IP,      /*!< PPP interface lost IP */
}

/**
 * @brief IPv4 address
 *
 */
struct esp_ip4_addr_t
{
    uint addr; /*!< IPv4 address */
}

struct esp_netif_ip_info_t
{
    esp_ip4_addr_t ip;      /**< Interface IPV4 address */
    esp_ip4_addr_t netmask; /**< Interface IPV4 netmask */
    esp_ip4_addr_t gw;      /**< Interface IPV4 gateway address */
}

/**
 * @brief Event structure for IP_EVENT_GOT_IP event
 *
 */
struct ip_event_got_ip_t
{
    int if_index;                /*!< Interface index for which the event is received (left for legacy compilation) */
    esp_netif_t* esp_netif;      /*!< Pointer to corresponding esp-netif object */
    esp_netif_ip_info_t ip_info; /*!< IP address, netmask, gatway IP address */
    bool ip_changed;             /*!< Whether the assigned IP has changed or not */
}

/**
 * @brief  Initialize the underlying TCP/IP stack
 *
 * @return
 *         - ESP_OK on success
 *         - ESP_FAIL if initializing failed

 * @note This function should be called exactly once from application code, when the application starts up.
 */
esp_err_t esp_netif_init();

/** @brief IP event base declaration */
extern __gshared esp_event_base_t IP_EVENT;
