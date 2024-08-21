module app.pong.pong;

import app.pong.drawer : PongDrawer;
import app.vga.color : Color;

import idf.esp_driver_gpio.gpio;
import idf.esp_timer : esp_timer_get_time;
import idf.freertos : vTaskDelay;

import idfd.log : Logger;

@safe:

struct Pong(uint ct_width, uint ct_height, int ct_pinUp, int ct_pinDown)
{
    enum log = Logger!"Pong"();

    private enum long ct_pollingRateUs = 10_000;
    private enum int ct_moveSpeed = 4;

    private PongDrawer!(ct_width, ct_height) m_pongDrawer;
    private long m_lastInputCheck;

scope:
    @trusted
    void initialize()
    {
        m_pongDrawer.initialize;

        gpio_set_direction(cast(gpio_num_t) ct_pinUp, GPIO_MODE_INPUT);
        gpio_set_pull_mode(cast(gpio_num_t) ct_pinUp, GPIO_PULLDOWN_ONLY);

        gpio_set_direction(cast(gpio_num_t) ct_pinDown, GPIO_MODE_INPUT);
        gpio_set_pull_mode(cast(gpio_num_t) ct_pinDown, GPIO_PULLDOWN_ONLY);
    }

    @trusted
    void tick()
    {
        long now = esp_timer_get_time();
        if (now - m_lastInputCheck >= ct_pollingRateUs)
        {
            m_lastInputCheck = now;

            short inputSpeed;
            if (gpio_get_level(cast(gpio_num_t) ct_pinUp))
                inputSpeed = -ct_moveSpeed;
            else if (gpio_get_level(cast(gpio_num_t) ct_pinDown))
                inputSpeed = ct_moveSpeed;

            if (inputSpeed)
                m_pongDrawer.moveBar(inputSpeed);
        }
    }

    nothrow @nogc
    void drawLine(Color[] buf, uint y)
        => m_pongDrawer.drawLine(buf, y);
}
