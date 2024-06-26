module idfd.signalio.router;

import idfd.signalio.gpio : GPIOPin;
import idfd.signalio.signal : Signal;

import idf.esp_driver_gpio.gpio : gpio_set_direction;
import idf.esp_rom.gpio : gpio_matrix_in, gpio_matrix_out;
import idf.hal.gpio_types : GPIO_MODE_DEF_INPUT, GPIO_MODE_DEF_OUTPUT, gpio_mode_t;
import idf.soc.gpio_num : gpio_num_t;
import idf.soc.gpio_periph : GPIO_PIN_MUX_REG;
import idf.soc.io_mux_reg : MCU_SEL_S, MCU_SEL_V, PIN_FUNC_GPIO;

@safe:

struct Route
{
    enum Type
    {
        FromPinToSignal,
        FromSignalToPin,
    }

    private Type m_type;
    private Signal m_signal;
    private GPIOPin m_pin;
    private bool m_inverted;

    @disable this();

    private this(Type type, Signal signal, GPIOPin pin, bool inverted)
    {
        m_type = type;
        m_signal = signal;
        m_pin = pin;
        m_inverted = inverted;
    }

    Type type() pure const => m_type;
    Signal signal() pure const => m_signal;
    GPIOPin pin() pure const => m_pin;
    bool inverted() pure const => m_inverted;
}

Route route(GPIOPin from, Signal to, bool invert = false) @trusted
in (from.supportsInput)
{
    ulong* muxRegElementPtr = cast(ulong*) cast(void*) GPIO_PIN_MUX_REG[from.pin];
    *muxRegElementPtr = (*muxRegElementPtr & ~(MCU_SEL_V << MCU_SEL_S)) | ((PIN_FUNC_GPIO & MCU_SEL_V) << MCU_SEL_S);

    // TODO: catch esp_err_t of gpio_set_direction
    gpio_set_direction(cast(gpio_num_t) from.pin, cast(gpio_mode_t) GPIO_MODE_DEF_INPUT);
    gpio_matrix_in(cast(uint) from.pin, cast(uint) to.signal, invert);

    return Route(Route.Type.FromPinToSignal, signal:to, pin:from, inverted:invert);
}

Route route(Signal from, GPIOPin to, bool invert = false) @trusted
in (to.supportsOutput)
{
    ulong* muxRegElementPtr = cast(ulong*) cast(void*) GPIO_PIN_MUX_REG[to.pin];
    *muxRegElementPtr = (*muxRegElementPtr & ~(MCU_SEL_V << MCU_SEL_S)) | ((PIN_FUNC_GPIO & MCU_SEL_V) << MCU_SEL_S);

    // TODO: catch esp_err_t of gpio_set_direction
    gpio_set_direction(cast(gpio_num_t) to.pin, cast(gpio_mode_t) GPIO_MODE_DEF_OUTPUT);
    gpio_matrix_out(cast(uint) to.pin, cast(uint) from.signal, invert, false);

    return Route(Route.Type.FromPinToSignal, signal:from, pin:to, inverted:invert);
}
