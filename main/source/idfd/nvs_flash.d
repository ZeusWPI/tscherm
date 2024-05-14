module idfd.nvs_flash;

import idfd.log : Logger;

import idf.esp_common.esp_err : esp_err_t, ESP_OK;
import idf.nvs_flash : ESP_ERR_NVS_NEW_VERSION_FOUND, ESP_ERR_NVS_NO_FREE_PAGES, nvs_flash_erase, nvs_flash_init;

@safe:

enum log = Logger!"nvs_flash"();

shared nvsFlashInitialized = false;

void initNvsFlash(bool eraseIfNeeded = true)() @trusted
{
    log.info!"Initializing NVS Flash...";
    static if (!eraseIfNeeded)
    {
        assert(nvs_flash_init == ESP_OK);
    }
    else
    {
        esp_err_t first_init_result = nvs_flash_init;
        if (first_init_result == ESP_ERR_NVS_NO_FREE_PAGES || first_init_result == ESP_ERR_NVS_NEW_VERSION_FOUND)
        {
          assert(nvs_flash_erase == ESP_OK);
          assert(nvs_flash_init == ESP_OK);
        }
        else
        {
            assert(first_init_result == ESP_OK);
        }
    }

    nvsFlashInitialized = true;
}
