module idf.soc.rtc;

@safe nothrow @nogc:

extern (C)
{
    void rtc_clk_apll_enable(bool enable, uint sdm0, uint sdm1, uint sdm2, uint o_div);
}
