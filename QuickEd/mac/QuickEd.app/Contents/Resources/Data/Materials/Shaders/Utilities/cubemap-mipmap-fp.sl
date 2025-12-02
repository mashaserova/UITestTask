#include "common.slh"

fragment_in
{
    float2 texCoord : TEXCOORD0;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

[auto][a] property float renderTargetId;
[auto][a] property float2 mipmapLevel;

uniform samplerCUBE cubemap;

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    #include "cubemap-faces.slh"

    int mipLevelWidth = pow(2, mipmapLevel.y - mipmapLevel.x - 1);
    float invWidth = 1.0 / (float)mipLevelWidth;

    int face = (int)renderTargetId;

    float3 N = normalize(faceNormals[face] + (texCoord.x * 2.0 - 1.0) * faceUs[face] + (texCoord.y * 2.0 - 1.0) * faceVs[face]);

    float3 s = texCUBElod(cubemap, N, 0.0).rgb;

    output.color.rgb = s;

    output.color.a = 1.0;

    return output;
}
