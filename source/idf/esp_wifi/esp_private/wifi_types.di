module idf.esp_wifi.esp_private.wifi_types;

@safe nothrow @nogc extern (C):
// dfmt off

/// WiFi ioctl command type
enum wifi_ioctl_cmd_t
{
    WIFI_IOCTL_SET_STA_HT2040_COEX = 1, /**< Set the configuration of STA's HT2040 coexist management */
    WIFI_IOCTL_GET_STA_HT2040_COEX,     /**< Get the configuration of STA's HT2040 coexist management */
    WIFI_IOCTL_MAX,
}

/// Configuration for STA's HT2040 coexist management
struct wifi_ht2040_coex_t
{
    int enable;                         /**< Indicate whether STA's HT2040 coexist management is enabled or not */
}

/// Configuration for WiFi ioctl
struct wifi_ioctl_config_t
{
    union Data
    {
        wifi_ht2040_coex_t ht2040_coex; /**< Configuration of STA's HT2040 coexist management */
    }
    Data data;                          /**< Configuration of ioctl command */
}