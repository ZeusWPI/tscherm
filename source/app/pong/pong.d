module app.pong.pong;

import app.pong.drawer : PongDrawer;
import app.pong.tcp_server : PongTcpServer;
import app.vga.framebuffer : FrameBuffer;

import idf.esp_driver_gpio.gpio;
import idf.esp_timer;
import idf.freertos : vTaskDelay;

import idfd.log : Logger;

@safe:

struct Pong
{
    enum log = Logger!"Pong"();

    private enum gpio_num_t m_pinUp = gpio_num_t.GPIO_NUM_12;
    private enum gpio_num_t m_pinDown = gpio_num_t.GPIO_NUM_13;
    private enum m_pollingRateUs = 10_000;
    private enum m_moveSpeed = 4;

    private PongDrawer m_pongDrawer;
    private PongTcpServer m_pongTcpServer;

scope:
    @trusted
    this(return scope FrameBuffer fb)
    {
        m_pongDrawer = PongDrawer(fb);

        gpio_set_direction(m_pinUp, GPIO_MODE_INPUT);
        gpio_set_pull_mode(m_pinUp, GPIO_PULLDOWN_ONLY);

        gpio_set_direction(m_pinDown, GPIO_MODE_INPUT);
        gpio_set_pull_mode(m_pinDown, GPIO_PULLDOWN_ONLY);

        long lastInputCheck;
        while (true)
        {
            long now = esp_timer_get_time();
            if (now - lastInputCheck >= m_pollingRateUs)
            {
                lastInputCheck = now;

                short inputSpeed;
                if (gpio_get_level(m_pinUp))
                    inputSpeed = -m_moveSpeed;
                else if (gpio_get_level(m_pinDown))
                    inputSpeed = m_moveSpeed;
                
                if (inputSpeed)
                {
                    m_pongDrawer.clearBar;
                    m_pongDrawer.moveBar(inputSpeed);
                    m_pongDrawer.drawBar;
                }
            }
            vTaskDelay(1);
        }
    }
}
