module idf.log;
// TODO: finish this binding

import idf.sdkconfig;

import core.stdc.stdarg : va_list;

@safe nothrow @nogc:

/// Log Level
enum esp_log_level_t
{
    ESP_LOG_NONE = 0, /// No log output.
    ESP_LOG_ERROR = 1, /// Critical errors, software module can not recover on its own.
    ESP_LOG_WARN = 2, /// Error conditions from which recovery measures have been taken.
    ESP_LOG_INFO = 3, /// Information messages which describe normal flow of events.
    ESP_LOG_DEBUG = 4, /// Extra information which is not necessary for normal use (values, pointers, sizes, etc).
    ESP_LOG_VERBOSE = 5, /// Bigger chunks of debugging information, or frequent messages which can potentially flood the output.
}

static if (is(typeof(CONFIG_LOG_MAXIMUM_LEVEL)))
    enum esp_log_level_t LOG_MAXIMUM_LEVEL = cast(esp_log_level_t) CONFIG_LOG_MAXIMUM_LEVEL;
else
    enum esp_log_level_t LOG_MAXIMUM_LEVEL = esp_log_level_t.ESP_LOG_INFO;

alias vprintf_like_t = int function(const char*, va_list);

static if (is(typeof(CONFIG_LOG_MASTER_LEVEL)))
{
    /**
     * Master log level.
     *
     * Optional master log level to check against for ESP_LOGx macros before calling
     * esp_log_write. Allows one to set a higher CONFIG_LOG_MAXIMUM_LEVEL but not
     * impose a performance hit during normal operation (only when instructed). An
     * application may set esp_log_set_level_master(level) to globally enforce a
     * maximum log level. ESP_LOGx macros above this level will be skipped immediately,
     * rather than calling esp_log_write and doing a cache hit.
     *
     * The tradeoff is increased application size.
     *
     * Params:
     *   level =  Master log level
     */
    extern (C)
    void esp_log_set_level_master(esp_log_level_t level);

    /**
     * Returns master log level.
     *
     * Returns: Master log level
     */
    extern (C)
    esp_log_level_t esp_log_get_level_master();
}

/**
 * Set log level for given tag.
 *
 * If logging for given component has already been enabled, changes previous setting.
 *
 * @note Note that this function can not raise log level above the level set using
 * CONFIG_LOG_MAXIMUM_LEVEL setting in menuconfig.
 * To raise log level above the default one for a given file, define
 * LOG_LOCAL_LEVEL to one of the ESP_LOG_* values, before including
 * esp_log.h in this file.
 *
 * Params:
 *   tag   = Tag of the log entries to enable. Must be a non-NULL zero terminated string.
 *           Value "*" resets log level for all tags to the given value.
 *   level = Selects log level to enable. Only logs at this and lower verbosity
 *           levels will be shown.
 */
extern (C)
void esp_log_level_set(const char* tag, esp_log_level_t level);

/**
 * Get log level for a given tag, can be used to avoid expensive log statements.
 *
 * Params:
 *   tag = Tag of the log to query current level. Must be a non-NULL zero terminated
 *         string.
 * Returns: The current log level for the given tag
 */
extern (C)
esp_log_level_t esp_log_level_get(const char* tag);

/**
 * Set function used to output log entries.
 *
 * By default, log output goes to UART0. This function can be used to redirect log
 * output to some other destination, such as file or network. Returns the original
 * log handler, which may be necessary to return output to the previous destination.
 *
 * Note:
 * Please note that function callback here must be re-entrant as it can be
 * invoked in parallel from multiple thread context.
 *
 * Params:
 *   func = new Function used for output. Must have same signature as vprintf.
 * Returns: `func` old Function used for output.
 */
extern (C)
vprintf_like_t esp_log_set_vprintf(vprintf_like_t func);

/**
 * Function which returns timestamp to be used in log output.
 *
 * This function is used in expansion of ESP_LOGx macros.
 * In the 2nd stage bootloader, and at early application startup stage
 * this function uses CPU cycle counter as time source. Later when
 * FreeRTOS scheduler start running, it switches to FreeRTOS tick count.
 *
 * For now, we ignore millisecond counter overflow.
 *
 * Returns: timestamp, in milliseconds.
 */
extern (C)
uint esp_log_timestamp();

/**
 * Function which returns system timestamp to be used in log output.
 *
 * This function is used in expansion of ESP_LOGx macros to print
 * the system time as "HH:MM:SS.sss". The system time is initialized to
 * 0 on startup, this can be set to the correct time with an SNTP sync,
 * or manually with standard POSIX time functions.
 *
 * Currently, this will not get used in logging from binary blobs
 * (i.e. Wi-Fi & Bluetooth libraries), these will still print the RTOS tick time.
 *
 * Returns: timestamp, in "HH:MM:SS.sss".
 */
extern (C)
char* esp_log_system_timestamp();

/**
 * Function which returns timestamp to be used in log output.
 *
 * This function uses HW cycle counter and does not depend on OS,
 * so it can be safely used after application crash.
 *
 * @return timestamp, in milliseconds
 */
extern (C)
uint esp_log_early_timestamp();

/**
 * Write message into the log.
 *
 * This function is not intended to be used directly. Instead, use one of
 * ESP_LOGE, ESP_LOGW, ESP_LOGI, ESP_LOGD, ESP_LOGV macros.
 *
 * This function or these macros should not be used from an interrupt.
 */
extern (C)
void esp_log_write(esp_log_level_t level, const char* tag, const char* format, scope const...);

/**
 * Write message into the log, va_list variant.
 *
 * This function is provided to ease integration toward other logging framework,
 * so that esp_log can be used as a log sink.
 *
 * See_Also: `esp_log_write`
 */
extern (C)
void esp_log_writev(esp_log_level_t level, const char* tag, const char* format, va_list args);

private extern (C)
{
    void esp_log_buffer_hex_internal(const char* tag, const void* buf, ushort bufLength, esp_log_level_t level);
    void esp_log_buffer_char_internal(const char* tag, const void* buf, ushort bufLength, esp_log_level_t level);
    void esp_log_buffer_hexdump_internal(const char* tag, const void* buf, ushort bufLength, esp_log_level_t level);
}

// Macros

/+

/**
 * Log a buffer of hex bytes at specified level, separated into 16 bytes each line.
 *
 * Params:
 *   tag      = description tag
 *   buffer   = Pointer to the buffer array
 *   buff_len = length of buffer in bytes
 *   level    = level of the log
 */
void ESP_LOG_BUFFER_HEX_LEVEL(string tag, esp_log_level_t level)(const void* buf, ushort bufLength)
{
    if (LOG_MAXIMUM_LEVEL >= level)
        esp_log_buffer_hex_internal(tag, buf, bufLength, level);
}

/**
 * Log a buffer of characters at specified level, separated into 16 bytes each line. Buffer should contain only printable characters.
 *
 * Params:
 *   tag      = description tag
 *   buffer   = Pointer to the buffer array
 *   buff_len = length of buffer in bytes
 *   level    = level of the log
 */
void ESP_LOG_BUFFER_CHAR_LEVEL(string tag, esp_log_level_t level)(const void* buf, ushort bufLength)
{
    if (LOG_MAXIMUM_LEVEL >= level)
        esp_log_buffer_char_internal(tag, buf, bufLength, level);
}

/**
 * Dump a buffer to the log at specified level.
 *
 * It is highly recommended to use terminals with over 102 text width.
 *
 * Params:
 *   tag      =  description tag
 *   buffer   =  Pointer to the buffer array
 *   buff_len =  length of buffer in bytes
 *   level    =  level of the log
 */
void ESP_LOG_BUFFER_HEXDUMP(string tag, esp_log_level_t level)(const void* buf, ushort bufLength)
{
    if (LOG_MAXIMUM_LEVEL >= level)
        esp_log_buffer_hexdump_internal(tag, buf, bufLength, level);
}

/**
 * Log a buffer of hex bytes at Info level
 *
 * Params:
 *   tag      = description tag
 *   buffer   = Pointer to the buffer array
 *   buff_len = length of buffer in bytes
 *
 * See_Also: `esp_log_buffer_hex_level`
 */
void ESP_LOG_BUFFER_HEX(string tag)(const void* buf, ushort bufLength)
{
    if (LOG_MAXIMUM_LEVEL >= ESP_LOG_INFO)
        ESP_LOG_BUFFER_HEX_LEVEL(tag, buf, bufLength, ESP_LOG_INFO);
}

/**
 * Log a buffer of characters at Info level. Buffer should contain only printable characters.
 *
 * Params:
 *   tag      = description tag
 *   buffer   = Pointer to the buffer array
 *   buff_len = length of buffer in bytes
 *
 * See_Also: `esp_log_buffer_char_level`
 */
void ESP_LOG_BUFFER_CHAR(string tag)(const void* buf, ushort bufLength)
{
    if (LOG_MAXIMUM_LEVEL >= ESP_LOG_INFO)
        ESP_LOG_BUFFER_CHAR_LEVEL(tag, buf, bufLength, ESP_LOG_INFO);
}

deprecated
{
    alias esp_log_buffer_hex = ESP_LOG_BUFFER_HEX;
    alias esp_log_buffer_char = ESP_LOG_BUFFER_CHAR;
}

static if (is(typeof(CONFIG_LOG_COLORS)))
{
    // dfmt off
    enum string LOG_COLOR_BLACK  = "30";
    enum string LOG_COLOR_RED    = "31";
    enum string LOG_COLOR_GREEN  = "32";
    enum string LOG_COLOR_BROWN  = "33";
    enum string LOG_COLOR_BLUE   = "34";
    enum string LOG_COLOR_PURPLE = "35";
    enum string LOG_COLOR_CYAN   = "36";
    enum string LOG_COLOR(string color) = "\033[0;" ~ color ~ "m";
    enum string LOG_BOLD(string color)  = "\033[1;" ~ color ~ "m";
    enum string LOG_RESET_COLOR  = "\033[0m";
    enum string LOG_COLOR_E      = LOG_COLOR!LOG_COLOR_RED;
    enum string LOG_COLOR_W      = LOG_COLOR!LOG_COLOR_BROWN;
    enum string LOG_COLOR_I      = LOG_COLOR!LOG_COLOR_GREEN;
    enum string LOG_COLOR_D      = "";
    enum string LOG_COLOR_V      = "";
    // dfmt on
}
else
{
    enum LOG_COLOR_E = "";
    enum LOG_COLOR_W = "";
    enum LOG_COLOR_I = "";
    enum LOG_COLOR_D = "";
    enum LOG_COLOR_V = "";
    enum LOG_RESET_COLOR = "";
}

enum string LOG_FORMAT(string shortLevelString, string format) = {
    return mixin("LOG_COLOR_" ~ shortLevelString) ~ " (%u) %s: " ~ format ~ LOG_RESET_COLOR ~ "\n";
}();

enum string LOG_SYSTEM_TIME_FORMAT(string shortLevelString, string format) = {
    return mixin("LOG_COLOR_" ~ shortLevelString) ~ " (%s) %s: " ~ format ~ LOG_RESET_COLOR ~ "\n";
}();

alias ESP_LOGE(string tag, string format) = ESP_LOG_LEVEL!(esp_log_level_t.ESP_LOG_ERROR, tag, format);
alias ESP_LOGW(string tag, string format) = ESP_LOG_LEVEL!(esp_log_level_t.ESP_LOG_WARN, tag, format);
alias ESP_LOGI(string tag, string format) = ESP_LOG_LEVEL!(esp_log_level_t.ESP_LOG_INFO, tag, format);
alias ESP_LOGD(string tag, string format) = ESP_LOG_LEVEL!(esp_log_level_t.ESP_LOG_DEBUG, tag, format);
alias ESP_LOGV(string tag, string format) = ESP_LOG_LEVEL!(esp_log_level_t.ESP_LOG_VERBOSE, tag, format);

/**
 * Runtime macro to output logs at a specified level.
 *
 * Params:
 *   tag    = tag of the log, which can be used to change the log level by `esp_log_level_set` at runtime.
 *   level  = level of the output log.
 *   format = format of the output log. See `printf`.
 *   ...    = variables to be replaced into the log. See `printf`.
 *
 * See_Also: `printf`
 */
pragma(inline)
extern(C)
void ESP_LOG_LEVEL(esp_log_level_t level, string tag, string format, Args...)(Args args)
{
    static if (level == esp_log_level_t.ESP_LOG_NONE || LOG_MAXIMUM_LEVEL >= level)
        return;
    else
    {
        enum shortLevelString = {
            final switch (level)
            {
            case esp_log_level_t.ESP_LOG_ERROR:
                return "E";
            case esp_log_level_t.ESP_LOG_WARN:
                return "W";
            case esp_log_level_t.ESP_LOG_INFO:
                return "I";
            case esp_log_level_t.ESP_LOG_DEBUG:
                return "D";
            case esp_log_level_t.ESP_LOG_VERBOSE:
                return "V";
            }
        }();
        static if (is(typeof(CONFIG_LOG_TIMESTAMP_SOURCE_RTOS)))
        {
            enum formatWithPrefix = LOG_FORMAT(shortLevelString, format);
            esp_log_write(level, tag, formatWithPrefix, esp_log_timestamp, tag, args);
        }
        else static if (is(typeof(CONFIG_LOG_TIMESTAMP_SOURCE_SYSTEM)))
        {
            enum formatWithPrefix = LOG_SYSTEM_TIME_FORMAT(shortLevelString, format);
            esp_log_write(level, tag, formatWithPrefix, esp_log_system_timestamp, tag, args);
        }
        else
            static assert(false);
    }
}

+/
