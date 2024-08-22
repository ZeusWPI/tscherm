module app.pong.input;

import idf.esp_driver_gpio.gpio;

import idfd.log : Logger;

@safe:

struct PongInput(int ct_pinUp, int ct_pinDown)
{
    enum log = Logger!"PongInput"();

    private enum long ct_pollingRateUs = 10_000;

scope:
    @trusted
    void initialize()
    {
        gpio_set_direction(cast(gpio_num_t) ct_pinUp, GPIO_MODE_INPUT);
        gpio_set_pull_mode(cast(gpio_num_t) ct_pinUp, GPIO_PULLDOWN_ONLY);

        gpio_set_direction(cast(gpio_num_t) ct_pinDown, GPIO_MODE_INPUT);
        gpio_set_pull_mode(cast(gpio_num_t) ct_pinDown, GPIO_PULLDOWN_ONLY);
    }

    @trusted
    PongInputCheckResult check()
    {
        PongInputCheckResult result;

        if (gpio_get_level(cast(gpio_num_t) ct_pinUp))
            result.up = true;
        else if (gpio_get_level(cast(gpio_num_t) ct_pinDown))
            result.down = true;

        return result;
    }
}

struct PongInputCheckResult
{
    bool up : 1;
    bool down : 1;
}
