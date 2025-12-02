#ensuredefined VIEW_MODE_OVERDRAW_HEAT 0
#if VIEW_MODE_OVERDRAW_HEAT
    blending { src=one dst=one }
#else
    color_mask = a;
#endif

fragment_in {};
    
fragment_out
{
    float4  color : SV_TARGET0;
};

fragment_out fp_main( fragment_in input )
{
    fragment_out    output;

    output.color = float4(0.0, 0.0, 0.0, 1.0);

    #include "debug-overdraw-2d.slh"
    return output;
}
