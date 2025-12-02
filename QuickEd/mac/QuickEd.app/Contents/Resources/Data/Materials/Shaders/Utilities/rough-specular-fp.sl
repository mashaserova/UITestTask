#include "common.slh"
#include "pbr-utils.slh"
#include "ibl.slh"
#include "srgb.slh"

#define NUM_SAMPLES (512)

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
[auto][a] property float2 mipmapLevel; // x - current, y - total
uniform samplerCUBE cubemap;

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    #include "cubemap-faces.slh"

    int width = 1 << (int)mipmapLevel.y;;

    int face = (int)renderTargetId;

    float linearRoughness = RoughnessFromMip(mipmapLevel.x, mipmapLevel.y);

    float3 N = normalize(faceNormals[face] + (texCoord.x * 2.0 - 1.0) * faceUs[face] + (texCoord.y * 2.0 - 1.0) * faceVs[face]);
    float3 V = N;
    float NdotV = 1.0;

    float3 LD = 0.0;
    float totalWeight = 0.0;

    for(int i = 0; i < NUM_SAMPLES; i++)
    {
        float2 Xi = 0.0;
        Xi = Hammersley(i, NUM_SAMPLES);
        float3 H = ImportanceSampleGGX(Xi, linearRoughness, N);

        float3 L = -reflect(V, H);

        float NdotL = dot(N, L);
        float NdotH = dot(N, H);
        float HdotV = dot(H, V);

        float D = D_GGX(NdotH, linearRoughness);
        float pdf = (D * NdotH / (4.0 * HdotV)) + 0.0001;
        float saTexel  = 4.0 * _PI / (6.0 * float(width * width));
        float saSample = 1.0 / (float(NUM_SAMPLES) * pdf + 0.0001);

        float mipLevel = linearRoughness == 0.0 ? 0.0 : 0.5 * log2(saSample / saTexel);

        if(NdotL > 0.0)
        {
            float3 val = texCUBElod(cubemap, L, mipLevel).rgb;
            val *= NdotL;
            LD += val;
            totalWeight += NdotL;
        }
    }

    LD /= totalWeight;

    output.color.rgb = LD;
    output.color.a = 1.0;

    return output;
}
