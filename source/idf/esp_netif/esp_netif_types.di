module idf.esp_netif.esp_netif_types;

import idf.esp_common.esp_err : esp_err_t;
import idf.esp_event : esp_event_base_t;
import idf.esp_netif.esp_netif_ip_addr;

@safe nothrow @nogc extern (C):

// #include <stdbool.h>
// #include <stdint.h>
// #include "esp_event_base.h"
// #include "esp_err.h"
// #include "esp_netif_ip_addr.h"

// dfmt off
/**
 * @brief Definition of ESP-NETIF based errors
 */
enum ESP_ERR_ESP_NETIF_BASE                  = 0x5000;
enum ESP_ERR_ESP_NETIF_INVALID_PARAMS        = ESP_ERR_ESP_NETIF_BASE + 0x01;
enum ESP_ERR_ESP_NETIF_IF_NOT_READY          = ESP_ERR_ESP_NETIF_BASE + 0x02;
enum ESP_ERR_ESP_NETIF_DHCPC_START_FAILED    = ESP_ERR_ESP_NETIF_BASE + 0x03;
enum ESP_ERR_ESP_NETIF_DHCP_ALREADY_STARTED  = ESP_ERR_ESP_NETIF_BASE + 0x04;
enum ESP_ERR_ESP_NETIF_DHCP_ALREADY_STOPPED  = ESP_ERR_ESP_NETIF_BASE + 0x05;
enum ESP_ERR_ESP_NETIF_NO_MEM                = ESP_ERR_ESP_NETIF_BASE + 0x06;
enum ESP_ERR_ESP_NETIF_DHCP_NOT_STOPPED      = ESP_ERR_ESP_NETIF_BASE + 0x07;
enum ESP_ERR_ESP_NETIF_DRIVER_ATTACH_FAILED  = ESP_ERR_ESP_NETIF_BASE + 0x08;
enum ESP_ERR_ESP_NETIF_INIT_FAILED           = ESP_ERR_ESP_NETIF_BASE + 0x09;
enum ESP_ERR_ESP_NETIF_DNS_NOT_CONFIGURED    = ESP_ERR_ESP_NETIF_BASE + 0x0A;
enum ESP_ERR_ESP_NETIF_MLD6_FAILED           = ESP_ERR_ESP_NETIF_BASE + 0x0B;
enum ESP_ERR_ESP_NETIF_IP6_ADDR_FAILED       = ESP_ERR_ESP_NETIF_BASE + 0x0C;
enum ESP_ERR_ESP_NETIF_DHCPS_START_FAILED    = ESP_ERR_ESP_NETIF_BASE + 0x0D;

/** @brief Type of esp_netif_object server */
// struct esp_netif_obj;
// typedef struct esp_netif_obj esp_netif_t;
// TODO: properly type this
alias esp_netif_t = void;

/** @brief Type of DNS server */
enum esp_netif_dns_type_t
{
    ESP_NETIF_DNS_MAIN = 0, /**< DNS main server address*/
    ESP_NETIF_DNS_BACKUP,   /**< DNS backup server address (Wi-Fi STA and Ethernet only) */
    ESP_NETIF_DNS_FALLBACK, /**< DNS fallback server address (Wi-Fi STA and Ethernet only) */
    ESP_NETIF_DNS_MAX,
}

/** @brief DNS server info */
struct esp_netif_dns_info_t
{
    esp_ip_addr_t ip; /**< IPV4 address of DNS server */
}

/** @brief Status of DHCP client or DHCP server */
enum esp_netif_dhcp_status_t
{
    ESP_NETIF_DHCP_INIT = 0,   /**< DHCP client/server is in initial state (not yet started) */
    ESP_NETIF_DHCP_STARTED,    /**< DHCP client/server has been started */
    ESP_NETIF_DHCP_STOPPED,    /**< DHCP client/server has been stopped */
    ESP_NETIF_DHCP_STATUS_MAX,
}

/** @brief Mode for DHCP client or DHCP server option functions */
enum esp_netif_dhcp_option_mode_t
{
    ESP_NETIF_OP_START = 0,
    ESP_NETIF_OP_SET,       /**< Set option */
    ESP_NETIF_OP_GET,       /**< Get option */
    ESP_NETIF_OP_MAX
}

/** @brief Supported options for DHCP client or DHCP server */
enum esp_netif_dhcp_option_id_t
{
    ESP_NETIF_SUBNET_MASK                 = 1,  /**< Network mask */
    ESP_NETIF_DOMAIN_NAME_SERVER          = 6,  /**< Domain name server */
    ESP_NETIF_ROUTER_SOLICITATION_ADDRESS = 32, /**< Solicitation router address */
    ESP_NETIF_REQUESTED_IP_ADDRESS        = 50, /**< Request specific IP address */
    ESP_NETIF_IP_ADDRESS_LEASE_TIME       = 51, /**< Request IP address lease time */
    ESP_NETIF_IP_REQUEST_RETRY_TIME       = 52, /**< Request IP address retry counter */
    ESP_NETIF_VENDOR_CLASS_IDENTIFIER     = 60, /**< Vendor Class Identifier of a DHCP client */
    ESP_NETIF_VENDOR_SPECIFIC_INFO        = 43, /**< Vendor Specific Information of a DHCP server */
}

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

/** @brief IP event base declaration */
// TODO: use a template for this stuff
extern __gshared esp_event_base_t IP_EVENT;

/** Event structure for IP_EVENT_STA_GOT_IP, IP_EVENT_ETH_GOT_IP events  */

struct esp_netif_ip_info_t
{
    esp_ip4_addr_t ip;      /**< Interface IPV4 address */
    esp_ip4_addr_t netmask; /**< Interface IPV4 netmask */
    esp_ip4_addr_t gw;      /**< Interface IPV4 gateway address */
}

/** @brief IPV6 IP address information
 */
struct esp_netif_ip6_info_t
{
    esp_ip6_addr_t ip; /**< Interface IPV6 address */
}

/**
 * @brief Event structure for IP_EVENT_GOT_IP event
 *
 */
struct ip_event_got_ip_t
{
    int if_index;                /*!< Interface index for which the event is received (left for legacy compilation) */
    esp_netif_t *esp_netif;      /*!< Pointer to corresponding esp-netif object */
    esp_netif_ip_info_t ip_info; /*!< IP address, netmask, gatway IP address */
    bool ip_changed;             /*!< Whether the assigned IP has changed or not */
}

/** Event structure for IP_EVENT_GOT_IP6 event */
struct ip_event_got_ip6_t
{
    int if_index;                  /*!< Interface index for which the event is received (left for legacy compilation) */
    esp_netif_t *esp_netif;        /*!< Pointer to corresponding esp-netif object */
    esp_netif_ip6_info_t ip6_info; /*!< IPv6 address of the interface */
    int ip_index;                  /*!< IPv6 address index */
}

/** Event structure for ADD_IP6 event */
struct ip_event_add_ip6_t
{
    esp_ip6_addr_t addr; /*!< The address to be added to the interface */
    bool preferred;      /*!< The default preference of the address */
}

/** Event structure for IP_EVENT_AP_STAIPASSIGNED event */
struct ip_event_ap_staipassigned_t
{
    esp_ip4_addr_t ip; /*!< IP address which was assigned to the station */
}

enum esp_netif_flags_t
{
    ESP_NETIF_DHCP_CLIENT            = 1 << 0,
    ESP_NETIF_DHCP_SERVER            = 1 << 1,
    ESP_NETIF_FLAG_AUTOUP            = 1 << 2,
    ESP_NETIF_FLAG_GARP              = 1 << 3,
    ESP_NETIF_FLAG_EVENT_IP_MODIFIED = 1 << 4,
    ESP_NETIF_FLAG_IS_PPP            = 1 << 5,
    ESP_NETIF_FLAG_IS_SLIP           = 1 << 6,
    ESP_NETIF_FLAG_MLDV6_REPORT      = 1 << 7,
}

enum esp_netif_ip_event_type_t
{
    ESP_NETIF_IP_EVENT_GOT_IP  = 1,
    ESP_NETIF_IP_EVENT_LOST_IP = 2,
}

//
// ESP-NETIF interface configuration:
//   1) general (behavioral) config (esp_netif_config_t)
//   2) (peripheral) driver specific config (esp_netif_driver_ifconfig_t)
//   3) network stack specific config (esp_netif_net_stack_ifconfig_t) -- no publicly available
//

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
    const char * if_key;                /*!< string identifier of the interface */
    const char * if_desc;               /*!< textual description of the interface */
    int route_prio;                     /*!< numeric priority of this interface to become a default
                                             routing if (if other netifs are up).
                                             A higher value of route_prio indicates
                                             a higher priority */
}

/**
 * @brief  IO driver handle type
 */
alias esp_netif_iodriver_handle = void*;

/**
 * @brief ESP-netif driver base handle
 *
 */
struct esp_netif_driver_base_t
{
    esp_err_t function(esp_netif_t *netif, esp_netif_iodriver_handle h) post_attach; /*!< post attach function pointer */
    esp_netif_t* netif; /*!< netif handle */
}

/**
 * @brief  Specific IO driver configuration
 */
struct esp_netif_driver_ifconfig_t
{
    esp_netif_iodriver_handle handle; /*!< io-driver handle */
    esp_err_t function(void* h, void* buffer, size_t len) transmit; /*!< transmit function pointer */
    esp_err_t function(void* h, void* buffer, size_t len, void* netstack_buffer) transmit_wrap; /*!< transmit wrap function pointer */
    void function(void* h, void* buffer) driver_free_rx_buffer; /*!< free rx buffer function pointer */
}

/**
 * @brief  Specific L3 network stack configuration
 */
// typedef struct esp_netif_netstack_config esp_netif_netstack_config_t;
// TODO: properly type this
alias esp_netif_netstack_config_t = void;

/**
 * @brief  Generic esp_netif configuration
 */
struct esp_netif_config_t
{
    const esp_netif_inherent_config_t* base;   /*!< base config */
    const esp_netif_driver_ifconfig_t* driver; /*!< driver config */
    const esp_netif_netstack_config_t* stack;  /*!< stack config */
}
// dfmt off

/**
 * @brief  ESP-NETIF Receive function type
 */
alias esp_netif_receive_t = esp_err_t function(esp_netif_t* esp_netif, void* buffer, size_t len, void* eb);
