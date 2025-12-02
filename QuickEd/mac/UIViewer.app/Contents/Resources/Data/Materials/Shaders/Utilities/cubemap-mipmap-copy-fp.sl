#include "common.slh"
#include "srgb.slh"

fragment_in
{
    float2 texCoord : TEXCOORD0;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

[auto][a] property float renderTargetId;
[auto][a] property float convertSRGBToLinear;
[auto][a] property float gamma;
[auto][a] property float multiplier;
[auto][a] property float groundFactor;

uniform samplerCUBE cubemap;

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    #include "cubemap-faces.slh"

    int face = (int)renderTargetId;

    float3 N = normalize(faceNormals[face] + (texCoord.x * 2.0 - 1.0) * faceUs[face] + (texCoord.y * 2.0 - 1.0) * faceVs[face]);

    float3 color = texCUBElod(cubemap, N, 0.0).rgb;

    output.color.rgb = color;

    if(convertSRGBToLinear > 0.0)
    {
        output.color.rgb = float3(SRGBToLinear(output.color.r), SRGBToLinear(output.color.g), SRGBToLinear(output.color.b));
    }

    output.color.rgb = pow(output.color.rgb, gamma) * multiplier * saturate(N.z + groundFactor * 2.0);

    output.color.a = 1.0;

    return output;
}
