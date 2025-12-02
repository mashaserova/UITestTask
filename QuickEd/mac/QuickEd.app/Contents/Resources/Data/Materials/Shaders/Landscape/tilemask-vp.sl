#include "common.slh"

#if LANDSCAPE_USE_INSTANCING
    vertex_in
    {
        [vertex] float4 data0 : TEXCOORD0; // position + edgeShiftDirection
        [vertex] float4 data1 : TEXCOORD1; // edge mask
        [vertex] float2 data2 : TEXCOORD2; // edgeVertexIndex + edgeMaskNull

        [instance] float3 data3 : TEXCOORD3; // patch position + scale
        [instance] float4 data4 : TEXCOORD4; // neighbour patch lodOffset
        #if LANDSCAPE_LOD_MORPHING
            [instance] float4 data5 : TEXCOORD5; // neighbour patch morph
            [instance] float3 data6 : TEXCOORD6; // patch lod + morph + pixelMappingOffset
        #endif
    };
#else
    vertex_in
    {
        float4 pos : POSITION;
        float2 uv : TEXCOORD0;
    };
#endif

vertex_out
{
    float4 pos : SV_POSITION;
#if DRAW_DEPTH_ONLY
    float4 projectedPosition : TEXCOORD0;
#else
    float2 texCoord : TEXCOORD0;
    float2 texCoordTiled : TEXCOORD1; // merging with other varying will result in precision loss on mali-400 [MOBWOT-75195]

    #if LANDSCAPE_MORPHING_COLOR
        float4 morphColor : COLOR0;
    #endif
    
    #if RECEIVE_SHADOW || LANDSCAPE_PBR
        float4 worldPos : COLOR1;
    #endif
    #if RECEIVE_SHADOW
        float4 projectedPosition : COLOR2;
        float3 shadowPos : COLOR5;
    #endif

    #if USE_VERTEX_FOG
        float4 varFog : TEXCOORD5;
    #endif
#endif
};

#if LANDSCAPE_USE_INSTANCING
    uniform sampler2D heightmap;
#endif

[auto][a] property float4x4 worldViewProjMatrix;

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if LANDSCAPE_USE_INSTANCING
    [auto][a] property float3 boundingBoxSize;
    [auto][a] property float heightmapTextureSize;
#endif

#if !DRAW_DEPTH_ONLY
    [material][instance] property float2 textureTiling = float2(50,50);

    #if USE_FOG_HALFSPACE || RECEIVE_SHADOW || LANDSCAPE_PBR
        [auto][a] property float4x4 worldMatrix;
    #endif
    #if USE_VERTEX_FOG
        [auto][a] property float3 cameraPosition;
        [auto][a] property float4x4 worldViewMatrix;

        #if (FOG_ATMOSPHERE)
            [auto][a] property float4 lightPosition0;
        #endif
        #include "vp-fog-props.slh"
    #endif
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out  output;
    
    #if !DRAW_DEPTH_ONLY
        output.texCoord = float2(0.0, 0.0);
    #endif

    #if LANDSCAPE_USE_INSTANCING

        float2 in_pos = input.data0.xy;
        float2 edgeShiftDirection = input.data0.zw;
        float4 edgeMask = input.data1;
        float edgeVertexIndex = input.data2.x;

        float3 patchOffsetScale = input.data3.xyz;
        float4 neighbourPatchLodOffset = input.data4;

        //Calculate vertecies offset for fusing neighboring patches
        float lodOffset = dot(edgeMask, neighbourPatchLodOffset);
        float edgeShiftAmount = pow(2.0, lodOffset);
        in_pos += edgeShiftDirection * fmod(edgeVertexIndex, edgeShiftAmount);

        float2 relativePosition = patchOffsetScale.xy + in_pos.xy * patchOffsetScale.z; //[0.0, 1.0]

        #if LANDSCAPE_LOD_MORPHING
            
            float edgeMaskNull = input.data2.y; //if all components of edgeMask is zero - this value is 0.0, othewise - 1.0. Used for a little optimization.
            float4 neighbourPatchMorph = input.data5;
            
            float baseLod = input.data6.x;
            float patchMorph = input.data6.y;
            float basePixelOffset = input.data6.z;
            
            //Calculate 'zero-multiplier' that provide fetch zero-mip for vertecies at the edges with climbs beyound height-texture. 
            float2 zeroLod = step(1.0, relativePosition);
            float zeroLodMul = 1.0 - min(1.0, zeroLod.x + zeroLod.y);

            //Calculate fetch parameters
            float sampleLod = (baseLod + lodOffset) * zeroLodMul;
            float samplePixelOffset = basePixelOffset * edgeShiftAmount * zeroLodMul; //mul by 'edgeShiftAmount' give 0.5 / ( 2 ^ ( baseLod + lodOffset ) )
            float4 heightmapSample = tex2Dlod(heightmap, float2(relativePosition + samplePixelOffset), sampleLod);

            //Calculate morphed height. 
            float morphAmount = dot(edgeMask, neighbourPatchMorph) + patchMorph * edgeMaskNull;
            // float h0 = dot(heightmapSample.xy, float2(0.0038910506, 0.99610895)); // 'accurate' height
            // float h1 = dot(heightmapSample.zw, float2(0.0038910506, 0.99610895)); // 'averaged' height
            // float height = lerp(h1, h0, morphAmount);

            // This code make the same thing as the code above, but potentially using fewer multiplications
            float2 hmSampleMorphed = lerp(heightmapSample.zw, heightmapSample.xy, morphAmount);
            float height = dot(hmSampleMorphed, float2(0.0038910506, 0.99610895));
        #else
            #if HEIGHTMAP_FLOAT_TEXTURE
                float height = tex2Dlod(heightmap, float2(relativePosition + 0.5 / heightmapTextureSize), 0.0).r;
            #else	
                float4 heightmapSample = tex2Dlod(heightmap, float2(relativePosition + 0.5 / heightmapTextureSize), 0.0);
                float height = dot(heightmapSample, float4(0.00022888532845, 0.00366216525521, 0.05859464408331, 0.93751430533303));
            #endif
        #endif

        float3 vx_position = float3( relativePosition - 0.5, height ) * boundingBoxSize;
        output.pos = mul( float4(vx_position.x, vx_position.y, vx_position.z, 1.0), worldViewProjMatrix );
        
        #if !DRAW_DEPTH_ONLY
            #if LANDSCAPE_LOD_MORPHING && LANDSCAPE_MORPHING_COLOR
                    output.morphColor = float4(1.0 - morphAmount, morphAmount, 1.0, 1.0);
                #endif
            
            output.texCoord = float2(relativePosition.x, 1.0 - relativePosition.y);
        #endif
    #else
        float3 vx_position = input.pos.xyz;
        output.pos = mul(float4(vx_position.x, vx_position.y, vx_position.z, 1.0), worldViewProjMatrix);
        
        #if !DRAW_DEPTH_ONLY
            output.texCoord = input.uv;
        #endif
    #endif
    
    #if DRAW_DEPTH_ONLY
        output.projectedPosition = output.pos;
    #else
        #if LANDSCAPE_RELAXMAP && LANDSCAPE_USE_RELAXMAP
            output.texCoordTiled = textureTiling.xy;
        #else
            output.texCoordTiled = output.texCoord.xy * textureTiling.xy;
        #endif
        
        #if USE_FOG_HALFSPACE || RECEIVE_SHADOW || LANDSCAPE_PBR
            float3 world_position = mul( float4(vx_position.xyz,1.0), worldMatrix ).xyz;
        #endif
        #if RECEIVE_SHADOW || LANDSCAPE_PBR
            output.worldPos = float4(world_position, 1.0);
        #endif
        
        #if RECEIVE_SHADOW
            output.projectedPosition = output.pos;
            float4 shadowViewPos = mul(output.worldPos, shadowViewMatrix);
            output.shadowPos = shadowViewPos.xyz;
        #endif
        
        #if USE_VERTEX_FOG
            float3 view_position = mul( float4(vx_position.xyz,1.0), worldViewMatrix ).xyz;
            #define FOG_view_position view_position

            #if FOG_ATMOSPHERE
                float3 tolight_dir = lightPosition0.xyz - view_position * lightPosition0.w;
                #define FOG_to_light_dir tolight_dir
            #endif

            #if USE_FOG_HALFSPACE
                #define FOG_world_position world_position
            #endif

            #define FOG_eye_position cameraPosition

            #include "vp-fog-math.slh" // in{ float3 FOG_view_position, float3 FOG_eye_position, float3 FOG_to_light_dir, float3 FOG_world_position }; out{ float4 FOG_result };
            
            output.varFog = FOG_result;
        #endif
    #endif

    return output;
}
