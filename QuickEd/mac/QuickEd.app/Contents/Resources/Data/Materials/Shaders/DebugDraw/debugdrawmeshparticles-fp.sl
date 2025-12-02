#include "blending.slh"

fragment_in
{
};

fragment_out
{
    float4  color : SV_TARGET0;
};

[material][a] property float4  color ;


fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    output.color = color;
    
    #if VIEW_MODE_OVERDRAW_HEAT
        output.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    #endif
    return output;
}
