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
[auto][a] property float2 renderTargetSize;
uniform sampler2D envmap;

float2 EnvmapUV(float3 v)
{
    float2 invAtan = float2(0.1591, 0.3183);
    float2 uv = float2(atan2(v.y, -v.x), asin(-v.z));
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    #include "cubemap-faces.slh"

    int width = (int)renderTargetSize.x;
    int height = (int)renderTargetSize.y;
    float invWidth = 1.0 / (float)width;
    float invHeight = 1.0 / (float)height;

    int face = (int)renderTargetId;

    float3 N = normalize(faceNormals[face] + (texCoord.x * 2.0 - 1.0) * faceUs[face] + (texCoord.y * 2.0 - 1.0) * faceVs[face]);

    float2 envmapTexCoord = EnvmapUV(N);

    output.color.rgb = tex2D(envmap, envmapTexCoord).rgb;
    //output.color.rgb = float3(LinearToSRGB(output.color.r), LinearToSRGB(output.color.g), LinearToSRGB(output.color.b));
    output.color.a = 1.0;

    return output;
}
