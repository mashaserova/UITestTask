#include "common.slh"
#include "srgb.slh"

fragment_in
{
    float2 positionNDC : TEXCOORD0;
    float2 texCoord : TEXCOORD1;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D luminance;

[auto][a] property float exposure;

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float gamma = 2.2;

    float2 texCoord = input.texCoord;
    float3 luminanceSample = tex2D(luminance, texCoord).rgb;

    float3 mappedColor = 1.0 - exp(-luminanceSample * exposure);

    output.color.rgb = luminanceSample * exposure;//float3(LinearToSRGB(mappedColor.r), LinearToSRGB(mappedColor.g), LinearToSRGB(mappedColor.b));

    return output;
}
