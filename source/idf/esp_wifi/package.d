module idf.esp_wifi;

public import idf.esp_wifi.idf_esp_wifi_c_code;

@safe:

wifi_init_config_t WIFI_INIT_CONFIG_DEFAULT() @trusted => WIFI_INIT_CONFIG_DEFAULT_CFunc;
