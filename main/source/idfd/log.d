module idfd.log;

import idf.log;
import idf.sdkconfig;

import std.traits : ReturnType, Unqual;

@safe nothrow @nogc:

private enum Level : esp_log_level_t
{
    // dfmt off
    none  = esp_log_level_t.ESP_LOG_NONE,
    error = esp_log_level_t.ESP_LOG_ERROR,
    warn  = esp_log_level_t.ESP_LOG_WARN,
    info  = esp_log_level_t.ESP_LOG_INFO,
    dbg   = esp_log_level_t.ESP_LOG_DEBUG,
    verb  = esp_log_level_t.ESP_LOG_VERBOSE,
    // dfmt on
}

private auto timestampFunc()
{
    static if (is(typeof(CONFIG_LOG_TIMESTAMP_SOURCE_RTOS)))
        return esp_log_timestamp;
    else static if (is(typeof(CONFIG_LOG_TIMESTAMP_SOURCE_SYSTEM)))
        return esp_log_system_timestamp;
    else
        static assert(false, "Could not determine the timestamp function");
}

private enum string timestampFormatSpecifier = {
    alias returnType = Unqual!(ReturnType!timestampFunc);
    static if (is(returnType == uint))
        return "%u";
    else static if (is(returnType == char*))
        return "%s";
    else
        static assert(false, "Timestamp function return type not recognized.");
}();

struct Logger(string tag)
{
    static assert(!is(typeof(this).sizeof)); // Opaque struct

pragma(inline):
    private void log(Level level, string format, Args...)(Args args)
    {
        static if (LOG_MAXIMUM_LEVEL <= level)
        {
            enum formatString = "(" ~ timestampFormatSpecifier ~ ") %s: " ~ format ~ "\n";
            esp_log_write(
                level,
                &tag[0],
                &formatString[0],
                esp_log_timestamp, &tag[0], args
            );
        }
    }

    // dfmt off
    void error(string format, Args...)(Args args) => log!(Level.error, format)(args);
    void warn (string format, Args...)(Args args) => log!(Level.warn,  format)(args);
    void info (string format, Args...)(Args args) => log!(Level.info,  format)(args);
    void dbg  (string format, Args...)(Args args) => log!(Level.dbg,   format)(args);
    void verb (string format, Args...)(Args args) => log!(Level.verb,  format)(args);
    // dfmt on
}

@("Test Logger")
unittest
{
    Logger!"test" log;
    log.info!"%s %d"(&"Testing"[0], 123);
}
