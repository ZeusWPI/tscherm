module idf.esp_wifi.esp_private.wifi_os_adapter;

import core.stdc.stdarg : va_list;

@safe nothrow @nogc extern (C):

// dfmt off
enum ESP_WIFI_OS_ADAPTER_VERSION = 0x00000008;
enum ESP_WIFI_OS_ADAPTER_MAGIC   = 0xDEADBEAF;

enum OSI_FUNCS_TIME_BLOCKING = 0xffffffff;

enum OSI_QUEUE_SEND_FRONT     = 0;
enum OSI_QUEUE_SEND_BACK      = 1;
enum OSI_QUEUE_SEND_OVERWRITE = 2;
// dfmt on

struct wifi_osi_funcs_t
{
    int _version;
    bool function() _env_is_chip;
    void function(int cpu_no, uint intr_source, uint intr_num, int intr_prio) _set_intr;
    void function(uint intr_source, uint intr_num) _clear_intr;
    void function(int n, void* f, void* arg) _set_isr;
    void function(uint mask) _ints_on;
    void function(uint mask) _ints_off;
    bool function() _is_from_isr;
    void* function() _spin_lock_create;
    void function(void* lock) _spin_lock_delete;
    uint function(void* wifi_int_mux) _wifi_int_disable;
    void function(void* wifi_int_mux, uint tmp) _wifi_int_restore;
    void function() _task_yield_from_isr;
    void* function(uint max, uint init) _semphr_create;
    void function(void* semphr) _semphr_delete;
    int function(void* semphr, uint block_time_tick) _semphr_take;
    int function(void* semphr) _semphr_give;
    void* function() _wifi_thread_semphr_get;
    void* function() _mutex_create;
    void* function() _recursive_mutex_create;
    void function(void* mutex) _mutex_delete;
    int function(void* mutex) _mutex_lock;
    int function(void* mutex) _mutex_unlock;
    void* function(uint queue_len, uint item_size) _queue_create;
    void function(void* queue) _queue_delete;
    int function(void* queue, void* item, uint block_time_tick) _queue_send;
    int function(void* queue, void* item, void* hptw) _queue_send_from_isr;
    int function(void* queue, void* item, uint block_time_tick) _queue_send_to_back;
    int function(void* queue, void* item, uint block_time_tick) _queue_send_to_front;
    int function(void* queue, void* item, uint block_time_tick) _queue_recv;
    uint function(void* queue) _queue_msg_waiting;
    void* function() _event_group_create;
    void function(void* event) _event_group_delete;
    uint function(void* event, uint bits) _event_group_set_bits;
    uint function(void* event, uint bits) _event_group_clear_bits;
    uint function(void* event, uint bits_to_wait_for, int clear_on_exit, int wait_for_all_bits, uint block_time_tick) _event_group_wait_bits;
    int function(void* task_func, const char* name, uint stack_depth, void* param, uint prio, void* task_handle, uint core_id) _task_create_pinned_to_core;
    int function(void* task_func, const char* name, uint stack_depth, void* param, uint prio, void* task_handle) _task_create;
    void function(void* task_handle) _task_delete;
    void function(uint tick) _task_delay;
    int function(uint ms) _task_ms_to_tick;
    void* function() _task_get_current_task;
    int function() _task_get_max_priority;
    void* function(uint size) _malloc;
    void function(void* p) _free;
    int function(const char* event_base, int event_id, void* event_data, size_t event_data_size, uint ticks_to_wait) _event_post;
    uint function() _get_free_heap_size;
    uint function() _rand;
    void function() _dport_access_stall_other_cpu_start_wrap;
    void function() _dport_access_stall_other_cpu_end_wrap;
    void function() _wifi_apb80m_request;
    void function() _wifi_apb80m_release;
    void function() _phy_disable;
    void function() _phy_enable;

    static if (is(typeof(CONFIG_IDF_TARGET_ESP32)) || is(typeof(CONFIG_IDF_TARGET_ESP32S2)))
    {
        void function() _phy_common_clock_enable;
        void function() _phy_common_clock_disable;
    }

    int function(const char* country) _phy_update_country_info;
    int function(ubyte* mac, uint type) _read_mac;
    void function(void* timer, uint tmout, bool repeat) _timer_arm;
    void function(void* timer) _timer_disarm;
    void function(void* ptimer) _timer_done;
    void function(void* ptimer, void* pfunction, void* parg) _timer_setfn;
    void function(void* ptimer, uint us, bool repeat) _timer_arm_us;
    void function() _wifi_reset_mac;
    void function() _wifi_clock_enable;
    void function() _wifi_clock_disable;
    void function() _wifi_rtc_enable_iso;
    void function() _wifi_rtc_disable_iso;
    long function() _esp_timer_get_time;
    int function(uint handle, const char* key, byte value) _nvs_set_i8;
    int function(uint handle, const char* key, byte* out_value) _nvs_get_i8;
    int function(uint handle, const char* key, ubyte value) _nvs_set_u8;
    int function(uint handle, const char* key, ubyte* out_value) _nvs_get_u8;
    int function(uint handle, const char* key, ushort value) _nvs_set_u16;
    int function(uint handle, const char* key, ushort* out_value) _nvs_get_u16;
    int function(const char* name, uint open_mode, uint* out_handle) _nvs_open;
    void function(uint handle) _nvs_close;
    int function(uint handle) _nvs_commit;
    int function(uint handle, const char* key, const void* value, size_t length) _nvs_set_blob;
    int function(uint handle, const char* key, void* out_value, size_t* length) _nvs_get_blob;
    int function(uint handle, const char* key) _nvs_erase_key;
    int function(ubyte* buf, size_t len) _get_random;
    int function(void* t) _get_time;
    ulong function() _random;

    static if (is(typeof(CONFIG_IDF_TARGET_ESP32S2)) || is(typeof(CONFIG_IDF_TARGET_ESP32S3)) || is(
            CONFIG_IDF_TARGET_ESP32C3))
    {
        uint function() _slowclk_cal_get;
    }

    void function(uint level, const char* tag, const char* format, ...) _log_write;
    void function(uint level, const char* tag, const char* format, va_list args) _log_writev;
    uint function() _log_timestamp;
    void* function(size_t size) _malloc_internal;
    void* function(void* ptr, size_t size) _realloc_internal;
    void* function(size_t n, size_t size) _calloc_internal;
    void* function(size_t size) _zalloc_internal;
    void* function(size_t size) _wifi_malloc;
    void* function(void* ptr, size_t size) _wifi_realloc;
    void* function(size_t n, size_t size) _wifi_calloc;
    void* function(size_t size) _wifi_zalloc;
    void* function(int queue_len, int item_size) _wifi_create_queue;
    void function(void* queue) _wifi_delete_queue;
    int function() _coex_init;
    void function() _coex_deinit;
    int function() _coex_enable;
    void function() _coex_disable;
    uint function() _coex_status_get;
    void function(uint type, bool dissatisfy) _coex_condition_set;
    int function(uint event, uint latency, uint duration) _coex_wifi_request;
    int function(uint event) _coex_wifi_release;
    int function(ubyte primary, ubyte secondary) _coex_wifi_channel_set;
    int function(uint event, uint* duration) _coex_event_duration_get;
    int function(uint event, ubyte* pti) _coex_pti_get;
    void function(uint type, uint status) _coex_schm_status_bit_clear;
    void function(uint type, uint status) _coex_schm_status_bit_set;
    int function(uint interval) _coex_schm_interval_set;
    uint function() _coex_schm_interval_get;
    ubyte function() _coex_schm_curr_period_get;
    void* function() _coex_schm_curr_phase_get;
    int function(int idx) _coex_schm_curr_phase_idx_set;
    int function() _coex_schm_curr_phase_idx_get;
    int _magic;
}

extern __gshared wifi_osi_funcs_t g_wifi_osi_funcs;
