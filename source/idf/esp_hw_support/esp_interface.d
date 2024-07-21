module idf.esp_hw_support.esp_interface;

@safe pure nothrow extern(C):

enum esp_interface_t
{
    ESP_IF_WIFI_STA = 0, /**< ESP32 station interface */
    ESP_IF_WIFI_AP,      /**< ESP32 soft-AP interface */
    ESP_IF_ETH,          /**< ESP32 ethernet interface */
    ESP_IF_MAX
}
