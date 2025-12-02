#include "common.slh"

vertex_in
{
    float3 position : POSITION;
    [instance] float4 worldMatrix0 : TEXCOORD1;
    [instance] float4 worldMatrix1 : TEXCOORD2;
    [instance] float4 worldMatrix2 : TEXCOORD3;
};

vertex_out
{
    float4  position : SV_POSITION;
};

[auto][a] property float4x4 viewProjMatrix;

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    float4x4 worldMatrix = float4x4(
        float4(input.worldMatrix0.x,  input.worldMatrix1.x,  input.worldMatrix2.x, 0.0),
        float4(input.worldMatrix0.y,  input.worldMatrix1.y,  input.worldMatrix2.y, 0.0),
        float4(input.worldMatrix0.z,  input.worldMatrix1.z,  input.worldMatrix2.z, 0.0),
        float4(input.worldMatrix0.w,  input.worldMatrix1.w,  input.worldMatrix2.w, 1.0)
    );
    
    float4 modelPos = float4(input.position.xyz, 1.0);
    float4 worldPos = mul(modelPos, worldMatrix);
    output.position = mul(worldPos, viewProjMatrix);

    return output;
}
