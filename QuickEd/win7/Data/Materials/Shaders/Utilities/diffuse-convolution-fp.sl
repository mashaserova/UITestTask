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
[auto][a] property float envMapSize;
uniform samplerCUBE cubemap;

float texelSolidAngle(float u_, float v_, float invSize_)
{
    float x0 = u_ - invSize_;
    float x1 = u_ + invSize_;
    float y0 = v_ - invSize_;
    float y1 = v_ + invSize_;
    float x00sq = x0 * x0;
    float x11sq = x1 * x1;
    float y00sq = y0 * y0;
    float y11sq = y1 * y1;
    return atan2(x0 * y0, sqrt(x00sq + y00sq + 1.0)) -
        atan2(x0 * y1, sqrt(x00sq + y11sq + 1.0)) -
        atan2(x1 * y0, sqrt(x11sq + y00sq + 1.0)) +
        atan2(x1 * y1, sqrt(x11sq + y11sq + 1.0));
}

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.texCoord;

    #include "cubemap-faces.slh"

    const float max_sampling_resolution = 16.0;

    float width = min(envMapSize, max_sampling_resolution);
    float height = width;

    float mip = log2(envMapSize) - log2(width);

    float invWidth = 1.0 / (float)width;
    float invHeight = 1.0 / (float)height;

    int face = (int)renderTargetId;

    float3 N = normalize(faceNormals[face] + (texCoord.x * 2.0 - 1.0) * faceUs[face] + (texCoord.y * 2.0 - 1.0) * faceVs[face]);

    float3 irradiance = 0.0;

    for(int f = 0; f < 6; f++)
    {
        float3 faceNormal = faceNormals[f];
        float3 faceU = faceUs[f];
        float3 faceV = faceVs[f];

        for(int i = 0; i < (int)width; i++)
        {
            float u = -1.0 + 2.0 * invWidth * (0.5 + i);
            for(int j = 0; j < (int)height; j++)
            {
                float v = -1.0 + 2.0 * invHeight * (0.5 + j);

                float3 direction = normalize(faceNormal + u * faceU + v * faceV);
                float cs = max(dot(direction, N), 0.0);
                float solidAngle = texelSolidAngle(u, v, invWidth);

                float3 val = texCUBElod(cubemap, direction, mip).rgb;
                //val = float3(SRGBToLinear(val.x), SRGBToLinear(val.y), SRGBToLinear(val.z));
                val = val * cs * solidAngle;
                irradiance += val;
            }
        }
    }

    output.color.rgb = irradiance * _INVERSE_PI;
    output.color.a = 1.0;

    return output;
}
