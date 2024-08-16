module idfd.signalio.i2s;

import idfd.log : Logger;
import idfd.signalio.signal : Signal;

import idf.driver.periph_ctrl : periph_module_enable;
import idf.esp_common.esp_err : ESP_ERROR_CHECK;
import idf.esp_hw_support.esp_intr_alloc : esp_intr_alloc, esp_intr_enable,
    ESP_INTR_FLAG_INTRDISABLED, ESP_INTR_FLAG_IRAM, ESP_INTR_FLAG_LEVEL3, intr_handle_t;
import idf.esp_rom.lldesc : lldesc_t;
import idf.freertos : eNotifyAction, TaskHandle_t, xTaskGenericNotifyFromISR;
import idf.soc.i2s_reg : I2S_INT_CLR_REG, I2S_INT_RAW_REG;
import idf.soc.i2s_struct : i2s_dev_t;
import idf.soc.periph_defs : periph_module_t;
import idf.soc.rtc : rtc_clk_apll_enable;

import ldc.attributes : section;

import ministd.algorithm : among;
import ministd.typecons : UniqueHeapArray;
import ministd.volatile : VolatileRef;

@safe:

struct I2SSignalGenerator(uint ct_i2sIndex, uint ct_bitCount, long ct_freq, bool ct_useInterrupt)
        if ((ct_i2sIndex == 0 && ct_bitCount == 8) || (ct_i2sIndex == 1 && ct_bitCount.among(8, 16)))
{
    private enum log = Logger!"I2SSignalGenerator"();

    private VolatileRef!i2s_dev_t m_i2sDev;

    static if (ct_useInterrupt)
    {
        private intr_handle_t m_interruptHandle;
        private TaskHandle_t m_taskToNotifyOnEofInterrupt;
    }

scope:
    @disable this();
    @disable this(ref typeof(this));

    /** 
     * Params:
     *   bitCount = Number of bits in one sample.
     *              This is equal to the number of generated signals.
     *   freq = Bit speed/frequency on each pin.
     *   i2sIndex = Which of the 2 I2S devices to use: `0` or `1`.
     */
    static if (!ct_useInterrupt)
    {
        void initialize()
        {
            initializeImpl;
        }
    }
    else
    {
        void initialize(TaskHandle_t taskToNotifyOnEofInterrupt)
        {
            m_taskToNotifyOnEofInterrupt = taskToNotifyOnEofInterrupt;
            initializeImpl;
        }
    }

    private pragma(inline, true)
    void initializeImpl()
    {
        m_i2sDev = VolatileRef!i2s_dev_t(i2sDevice!ct_i2sIndex);

        enable;
        reset;
        setupParallelOutput;
        setupClock;
        prepareForTransmitting;

        static if (ct_useInterrupt)
            allocateInterrupt;

        reset;
    }

    private
    void enable()
    {
        enum m = i2sPeripheralModule!(ct_i2sIndex);
        (() @trusted => periph_module_enable(m))();
    }

    private nothrow @nogc
    void reset()
    {
        import idf.soc.i2s_reg;

        enum uint lcConfResetFlags = I2S_IN_RST_M | I2S_OUT_RST_M | I2S_AHBM_RST_M | I2S_AHBM_FIFO_RST_M;
        enum uint confResetFlags = I2S_RX_RESET_M | I2S_RX_FIFO_RESET_M | I2S_TX_RESET_M | I2S_TX_FIFO_RESET_M;

        m_i2sDev.lc_conf.val |= lcConfResetFlags;
        m_i2sDev.lc_conf.val &= ~lcConfResetFlags;

        m_i2sDev.conf.val |= confResetFlags;
        m_i2sDev.conf.val &= ~confResetFlags;

        while (m_i2sDev.state.rx_fifo_reset_back)
        {
        }
    }

    private nothrow @nogc
    void setupParallelOutput()
    {
        // Clear serial mode flags
        m_i2sDev.conf.tx_msb_right = 0;
        m_i2sDev.conf.tx_msb_shift = 0;
        m_i2sDev.conf.tx_mono = 0;
        m_i2sDev.conf.tx_short_sync = 0;

        // Set parallel mode flags
        m_i2sDev.conf2.val = 0;
        m_i2sDev.conf2.lcd_en = 1;
        m_i2sDev.conf2.lcd_tx_wrx2_en = 1;
        m_i2sDev.conf2.lcd_tx_sdx2_en = 0;
    }

    private
    void setupClock()
    {
        long freq = ct_freq * 2 * (ct_bitCount / 8);

        m_i2sDev.sample_rate_conf.val = 0;
        m_i2sDev.sample_rate_conf.tx_bits_mod = ct_bitCount;
        int sdm, sdmn;
        int odir = -1;
        do
        {
            odir++;
            sdm = cast(int)((cast(long)(
                    ((cast(double) freq) / (20_000_000.0 / (odir + 2))) * 0x10000)) - 0x40000);
            sdmn = cast(int)(
                (cast(long)(((cast(double) freq) / (20_000_000.0 / (odir + 2 + 1))) * 0x10000)) - 0x40000);
        }
        while (sdm < 0x8c0ecL && odir < 31 && sdmn < 0xA1fff);
        if (sdm > 0xA1fff)
            sdm = 0xA1fff;

        // dfmt off
        () @trusted {
            rtc_clk_apll_enable(
                enable : true,
                sdm0 : sdm & 255,
                sdm1 : (sdm >> 8) & 255,
                sdm2 : sdm >> 16,
                o_div : odir,
            );
        }();
        // dfmt on

        {
            int clockN = 2, clockA = 1, clockB = 0, clockDiv = 1;

            m_i2sDev.clkm_conf.val = 0;
            m_i2sDev.clkm_conf.clka_en = 1;
            m_i2sDev.clkm_conf.clkm_div_num = clockN;
            m_i2sDev.clkm_conf.clkm_div_a = clockA;
            m_i2sDev.clkm_conf.clkm_div_b = clockB;
            m_i2sDev.sample_rate_conf.tx_bck_div_num = clockDiv;
        }
    }

    private nothrow @nogc
    void prepareForTransmitting()
    {
        m_i2sDev.fifo_conf.val = 0;
        m_i2sDev.fifo_conf.tx_fifo_mod_force_en = 1;
        m_i2sDev.fifo_conf.tx_fifo_mod = 1; //byte packing 0A0B_0B0C = 0, 0A0B_0C0D = 1, 0A00_0B00 = 3,
        m_i2sDev.fifo_conf.tx_data_num = 32; //fifo length
        m_i2sDev.fifo_conf.dscr_en = 1; //fifo will use dma

        m_i2sDev.conf1.val = 0;
        m_i2sDev.conf1.tx_stop_en = 0;
        m_i2sDev.conf1.tx_pcm_bypass = 1;

        m_i2sDev.conf_chan.val = 0;
        m_i2sDev.conf_chan.tx_chan_mod = 1;

        m_i2sDev.conf.tx_right_first = 1; // high or low (stereo word order)
        m_i2sDev.timing.val = 0;
    }

    static if (ct_useInterrupt)
    {
        private @trusted nothrow @nogc
        void allocateInterrupt()
        {
            ESP_ERROR_CHECK(esp_intr_alloc(
                    i2sInterruptSource!ct_i2sIndex,
                    ESP_INTR_FLAG_INTRDISABLED | ESP_INTR_FLAG_LEVEL3 | ESP_INTR_FLAG_IRAM,
                    &handleInterrupt,
                    &this,
                    &m_interruptHandle,
            ));
        }
    }

    /** 
     * Params:
     *   firstDescriptor = Pointer to a lldesc_t of which the next ptr can be followed infinitely.
     */
    void startTransmitting(return scope lldesc_t* firstDescriptor)
    {
        m_i2sDev.lc_conf.val = 0;
        m_i2sDev.lc_conf.out_data_burst_en = 1;
        m_i2sDev.lc_conf.outdscr_burst_en = 1;

        m_i2sDev.out_link.addr = cast(uint) firstDescriptor;
        m_i2sDev.out_link.start = 1;

        m_i2sDev.int_clr.val = m_i2sDev.int_raw.val;
        m_i2sDev.int_ena.val = 0;

        static if (ct_useInterrupt)
        {
            m_i2sDev.int_ena.out_eof = 1;
            ESP_ERROR_CHECK(esp_intr_enable(m_interruptHandle));
        }

        m_i2sDev.conf.tx_start = 1;
    }

    nothrow @nogc
    UniqueHeapArray!Signal getSignals() const
    {
        auto signals = UniqueHeapArray!Signal.create(ct_bitCount);

        enum uint firstSignalIndex = i2sFirstSignalIndex!(ct_i2sIndex, ct_bitCount);
        foreach (i, ref signal; signals)
            signal = Signal(firstSignalIndex + cast(uint) i);

        return signals;
    }

    @section(".iram1")
    private static @trusted nothrow @nogc extern (C)
    void handleInterrupt(void* arg)
    {
        import core.volatile : volatileLoad, volatileStore;
        import idf.soc.i2s_reg : I2S_INT_CLR_REG, I2S_INT_RAW_REG, I2S_OUT_EOF_DES_ADDR_REG, I2S_OUT_EOF_INT_RAW;

        enum uint* rawReg = cast(uint*)(I2S_INT_RAW_REG!ct_i2sIndex);
        enum uint* clrReg = cast(uint*)(I2S_INT_CLR_REG!ct_i2sIndex);

        uint rawFlags = volatileLoad(rawReg);
        volatileStore(clrReg, (rawFlags & 0xffffffc0) | 0x3f); // Clear interrupt flags

        I2SSignalGenerator* instance = cast(I2SSignalGenerator*) arg;

        if (rawFlags & I2S_OUT_EOF_INT_RAW)
        {
            uint currDescAddr = volatileLoad(cast(uint*) I2S_OUT_EOF_DES_ADDR_REG!ct_i2sIndex);

            // dfmt off
            xTaskGenericNotifyFromISR(
                xTaskToNotify: instance.m_taskToNotifyOnEofInterrupt,
                uxIndexToNotify: 0,
                ulValue: currDescAddr,
                eAction: eNotifyAction.eSetValueWithOverwrite,
                pulPreviousNotificationValue: null,
                pxHigherPriorityTaskWoken: null,
            );
            // dfmt on
        }
    }
}

template i2sDevice(uint i2sIndex)
{
    import idf.soc.i2s_struct : I2S0, I2S1;

    static if (i2sIndex == 0)
        enum i2s_dev_t* i2sDevice = &I2S0;
    else static if (i2sIndex == 1)
        enum i2s_dev_t* i2sDevice = &I2S1;
    else
        static assert(false);
}

template i2sPeripheralModule(uint i2sIndex)
{
    import idf.soc.periph_defs : PERIPH_I2S0_MODULE, PERIPH_I2S1_MODULE;

    static if (i2sIndex == 0)
        enum periph_module_t i2sPeripheralModule = PERIPH_I2S0_MODULE;
    else static if (i2sIndex == 1)
        enum periph_module_t i2sPeripheralModule = PERIPH_I2S1_MODULE;
    else
        static assert(false);
}

template i2sInterruptSource(uint i2sIndex)
{
    import idf.soc.soc : ETS_I2S0_INTR_SOURCE, ETS_I2S1_INTR_SOURCE;

    static if (i2sIndex == 0)
        enum int i2sInterruptSource = ETS_I2S0_INTR_SOURCE;
    else static if (i2sIndex == 1)
        enum int i2sInterruptSource = ETS_I2S1_INTR_SOURCE;
    else
        static assert(false);
}

template i2sFirstSignalIndex(uint i2sIndex, uint bitCount)
{
    import idf.soc.gpio_sig_map : I2S0O_DATA_OUT0_IDX, I2S1O_DATA_OUT0_IDX;

    static if (i2sIndex == 0)
    {
        enum uint i2sFirstSignalIndex = I2S0O_DATA_OUT0_IDX + 16;
    }
    else static if (i2sIndex == 1)
    {
        static if (bitCount == 8)
            enum uint i2sFirstSignalIndex = I2S1O_DATA_OUT0_IDX;
        else static if (m_bitCount == 16)
            enum uint i2sFirstSignalIndex = I2S1O_DATA_OUT0_IDX + 8;
        else
            static assert(false);
    }
    else
        static assert(false);
}
