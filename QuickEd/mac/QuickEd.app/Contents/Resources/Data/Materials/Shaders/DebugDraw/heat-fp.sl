#include "common.slh"
#ensuredefined VIEW_MODE_OVERDRAW_COUNT_ALPHABLEND 0
#ensuredefined VIEW_MODE_OVERDRAW_COUNT_ALPHATEST 0
#ensuredefined VIEW_MODE_FLIP_UV_HACK 0

fragment_in
{
    float2 texCoord : TEXCOORD0;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D image;
uniform sampler2D heatColorLUT;

fragment_out fp_main(fragment_in input)
{
    float2 sampleUv = input.texCoord.xy;
    #if VIEW_MODE_FLIP_UV_HACK
        sampleUv.y = lerp(1.0f - sampleUv.y, sampleUv.y, step(ndcToUvMapping.y, 0.0f));
    #endif
    float3 colorSample = tex2D(image, sampleUv).rgb;

    float heatTerm = 0.0f;
    #if VIEW_MODE_OVERDRAW_COUNT_ALPHABLEND
        heatTerm += colorSample.r;
    #endif
    #if VIEW_MODE_OVERDRAW_COUNT_ALPHATEST
        heatTerm += colorSample.g;
    #endif
    
    fragment_out output;    
    output.color = tex2D(heatColorLUT, float2(heatTerm, 0));
    return output;
}
