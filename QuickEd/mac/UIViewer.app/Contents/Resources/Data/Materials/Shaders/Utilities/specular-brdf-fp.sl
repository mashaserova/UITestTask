#include "common.slh"
#include "pbr-utils.slh"
#include "ibl.slh"

#define NUM_SAMPLES 4096

fragment_in
{
    float2 positionNDC : TEXCOORD0;
    float2 texCoord : TEXCOORD1;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

[auto][a] property float renderTargetId;
[auto][a] property float2 renderTargetSize;

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    float NdotV = float(texCoord.x);
    float linearRoughness = float(texCoord.y);

    float3 V = float3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);
    float3 N = float3(0.0, 0.0, 1.0);

    float2 result = 0.0;

    for(int i = 0; i < NUM_SAMPLES; i++)
    {
        float2 Xi = 0.0;
        Xi = Hammersley(i, NUM_SAMPLES);

        float3 H = ImportanceSampleGGX(Xi, linearRoughness, N);
        float3 L = reflect(-V, H);

        float NdotL = dot(N, L);
        float NdotV = dot(N, V);
        float NdotH = dot(N, H);
        float VdotH = dot(V, H);

        if(NdotL > 0.0)
        {
            float G = 0.0;

            //G = GeometrySmith(NdotV, NdotL, linearRoughness);
            G = G_SmithGGX(NdotL, NdotV, linearRoughness * linearRoughness * linearRoughness * linearRoughness);
            float Gv = G * VdotH / (NdotV * NdotH);
            float Fc = pow(1.0 - VdotH, 5.0);
            result.x += Gv * (1.0 - Fc);
            result.y += Gv * Fc;
        }
    }

    output.color.rg = result / float(NUM_SAMPLES);
    output.color.b = 0.0;
    output.color.a = 1.0;

    return output;
}
