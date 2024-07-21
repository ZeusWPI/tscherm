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

enum esp_netif_flags_t
{
    ESP_NETIF_DHCP_CLIENT = 1 << 0,
    ESP_NETIF_DHCP_SERVER = 1 << 1,
    ESP_NETIF_FLAG_AUTOUP = 1 << 2,
    ESP_NETIF_FLAG_GARP   = 1 << 3,
    ESP_NETIF_FLAG_EVENT_IP_MODIFIED = 1 << 4,
    ESP_NETIF_FLAG_IS_PPP = 1 << 5,
    ESP_NETIF_FLAG_IS_SLIP = 1 << 6,
    ESP_NETIF_FLAG_MLDV6_REPORT = 1 << 7,
}

/**
 * @brief ESP-netif inherent config parameters
 *
 */
struct esp_netif_inherent_config_t
{
    esp_netif_flags_t flags;            /*!< flags that define esp-netif behavior */
    ubyte[6] mac;                       /*!< initial mac address for this interface */
    const esp_netif_ip_info_t* ip_info; /*!< initial ip address for this interface */
    uint get_ip_event;                  /*!< event id to be raised when interface gets an IP */
    uint lost_ip_event;                 /*!< event id to be raised when interface losts its IP */
    const char* if_key;                 /*!< string identifier of the interface */
    const char* if_desc;                /*!< textual description of the interface */
    int route_prio;                     /*!< numeric priority of this interface to become a default
                                             routing if (if other netifs are up).
                                             A higher value of route_prio indicates
                                             a higher priority */
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
