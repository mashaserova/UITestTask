#include "common.slh"
#include "materials-vertex-properties.slh"

vertex_in
{
    float4 position : POSITION;
    float3 normal : NORMAL;

    #if HARD_SKINNING
        float index : BLENDINDICES;
    #endif
};

vertex_out
{
    float4 position : SV_POSITION;
};

[auto][a] property float4x4 worldViewProjMatrix;
[auto][a] property float4x4 worldViewMatrix;
[auto][a] property float4x4 projMatrix;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

[material][a] property float silhouetteScale = 1.0;
[material][a] property float silhouetteExponent = 0;

vertex_out vp_main(vertex_in input)
{
    vertex_out  output;

    float4 position;
    float3 normal;

    #if HARD_SKINNING
        float4 jQ = jointQuaternions[int(input.index)];
        position = HardSkinnedPosition(input.position.xyz, input.index);
        normal = JointTransformTangent(input.normal, jQ);
    #else
        position = float4(input.position.xyz, 1.0);
        normal = input.normal;
    #endif

    normal = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);
    float4 PosView = mul(position, worldViewMatrix);

    float distanceScale = length(PosView.xyz) / 100.0;

    PosView.xyz += normal * pow(silhouetteScale * distanceScale, silhouetteExponent);
    output.position = mul(PosView, projMatrix);

    return output;
}
