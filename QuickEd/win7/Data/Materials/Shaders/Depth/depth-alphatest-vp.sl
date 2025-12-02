#include "common.slh"
#define DRAW_DEPTH_ONLY 1
#include "materials-vertex-properties.slh"

vertex_in
{
    float3 position : POSITION;

    #if MATERIAL_TEXTURE
        float2 texcoord0 : TEXCOORD0;
    #endif
    
    #if USE_VERTEX_DISPLACEMENT
        float3 normal : NORMAL;
    #endif

    #if ALPHA_MASK || USE_VERTEX_DISPLACEMENT
        float2 texcoord1 : TEXCOORD1;
    #endif

    #if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
        float4 color0 : COLOR0;
    #endif

    #if WIND_ANIMATION
        float flexibility : TEXCOORD5;
    #elif VERTEX_VERTICAL_OFFSET
        float offsetWeight : TEXCOORD5;
    #endif
    
    #include "skinning-vertex-input.slh"
};

vertex_out
{
    float4 position : SV_POSITION;
    float4 projectedPosition : TEXCOORD0;

    #if MATERIAL_TEXTURE
        float2 varTexCoord0 : TEXCOORD1;
    #endif

    #if ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD2;
    #endif

    #if FLOWMAP
        [lowp] float3 varFlowData : TEXCOORD3; // For flowmap animations - xy next frame uv. z - frame time
    #endif

    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif
};

////////////////////////////////////////////////////////////////////////////////
// properties

[auto][a] property float4x4 worldViewProjMatrix;

#if TEXTURE0_SHIFT_ENABLED
    [material][a] property float2 texture0Shift = float2(0, 0);
#endif
#if TEXTURE0_ANIMATION_SHIFT
    [material][a] property float2 tex0ShiftPerSecond = float2(0, 0);
#endif

#if FLOWMAP
    [material][a] property float flowAnimSpeed = 0;
    [material][a] property float flowAnimOffset = 0;
#endif

#define NEED_CHAIN_TEXCOORD_OFFSETS 1
#if INSTANCED_CHAIN
    #include "instanced-chain.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out  output;

    #include "materials-vertex-processing.slh"

    #if FLOWMAP
        float flowSpeed = flowAnimSpeed;
        float flowOffset = flowAnimOffset;
        float scaledTime = globalTime * flowSpeed;
        float2 flowPhases = frac(float2(scaledTime, scaledTime+0.5))-float2(0.5, 0.5);
        float flowBlend = abs(flowPhases.x*2.0);
        output.varFlowData = float3(flowPhases * flowOffset, flowBlend);
    #endif

    #if VERTEX_COLOR
        output.varVertexColor = half4(input.color0);
    #endif

    #if MATERIAL_TEXTURE
        output.varTexCoord0.xy = input.texcoord0;
        #if INSTANCED_CHAIN
            const float texCoordScale = segmentLength / chunkLength;
            const float texCoordOffset = GetTexCoordOffset(instanceId + 1);
            output.varTexCoord0.y = texCoordOffset + texCoordScale * output.varTexCoord0.y;
        #endif
        #if PARTICLES_PERSPECTIVE_MAPPING
            output.varTexCoord0.z = input.texcoord5.z;
        #endif
    #endif

    #if MATERIAL_TEXTURE
        #if TEXTURE0_SHIFT_ENABLED
            output.varTexCoord0.xy += texture0Shift;
        #endif

        #if TEXTURE0_ANIMATION_SHIFT
            output.varTexCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
        #endif
    #endif

    #if ALPHA_MASK
        output.varTexCoord1 = input.texcoord1.xy;
    #endif

    #if FORCE_2D_MODE
        output.position.z = 0.0;
    #endif

    output.projectedPosition = output.position;

    return output;
}
