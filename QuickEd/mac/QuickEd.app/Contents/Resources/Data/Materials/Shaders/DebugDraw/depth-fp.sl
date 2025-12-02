#include "common.slh"

fragment_in
{
    float2 texCoord : TEXCOORD0;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D image;

fragment_out fp_main(fragment_in input)
{
    float2 depthRange = float2(0.9, 1.0); // todo : move to properties

    float depthSample = tex2D(image, input.texCoord.xy).x;

    fragment_out output;
    output.color = max(0.0, depthSample - depthRange.x) / (depthRange.y - depthRange.x);
    return output;
}
