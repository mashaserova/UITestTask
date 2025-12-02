#include "common.slh"
#include "lighting.slh"
#include "vp-fog-props.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"

#ensuredefined PBR_DECAL 0
#ensuredefined PBR_DETAIL 0

vertex_in
{
    float3 position : POSITION;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
    float3 binormal : BINORMAL;

    float2 texcoord0 : TEXCOORD0;

    #if PBR_LIGHTMAP || PBR_DECAL || USE_VERTEX_DISPLACEMENT
        float2 texcoord1 : TEXCOORD1;
    #endif

    #if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
        float4 color0 : COLOR0;
    #endif

    #if WIND_ANIMATION
        float flexibility : TEXCOORD5;
    #endif

    #if SOFT_SKINNING
        float4 indices : BLENDINDICES;
        float4 weights : BLENDWEIGHT;
    #elif HARD_SKINNING
        float index : BLENDINDICES;
    #endif
};

vertex_out
{
    float4 position : SV_POSITION;

    #if TILED_DECAL_MASK
        float4 varTexCoord0 : TEXCOORD0;
    #else
        float2 varTexCoord0 : TEXCOORD0;
    #endif

    #if PBR_LIGHTMAP || PBR_DECAL
        float2 varTexCoord1 : TEXCOORD1;
    #endif
    
    #if PBR_DETAIL
        float2 varTexCoord2 : TEXCOORD2;
    #endif

    [lowp] half3 varToLightVec : COLOR1;

    half3 tangentToWorld0 : TANGENTTOWORLD0;
    half3 tangentToWorld1 : TANGENTTOWORLD1;
    half3 tangentToWorld2 : TANGENTTOWORLD2;

    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        float4 projPos : COLOR2;
    #endif

    float4 worldPos : POSITION3;

    #if RECEIVE_SHADOW
        float3 shadowPos : COLOR5;
    #endif

    #if TILED_DECAL_MASK && TILED_DECAL_ANIMATED_EMISSION
        [lowp] half4 aniCamoParams : COLOR3;
    #endif

    #if NEEDS_LOCAL_POSITION
        half4 localPos : POSITION2; // xyz - position, w - normal.z
    #endif

    #if MULTIPLE_DECAL_TEXTURES
        half index : COLOR4;
    #endif
};

[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 worldInvTransposeMatrix;
[auto][a] property float4x4 worldViewProjMatrix;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if PBR_LIGHTMAP
    [material][a] property float2 pbrUvOffset = float2(0,0);
    [material][a] property float2 pbrUvScale = float2(0,0);
#endif

#if PBR_DETAIL
    [material][a] property float2 pbrDetailTileCoordScale = float2(1.0, 1.0);
#endif

#if DISTANCE_ATTENUATION
    [material][a] property float lightIntensity0 = 1.0;
#endif

[auto][a] property float4 lightPosition0;

#if TEXTURE0_SHIFT_ENABLED
    [material][a] property float2 texture0Shift = float2(0,0);
#endif

#if TEXTURE0_ANIMATION_SHIFT
    [material][a] property float2 tex0ShiftPerSecond = float2(0,0);
#endif

#if USE_VERTEX_FOG
    [auto][a] property float3 cameraPosition;
#endif

#if MULTIPLE_DECAL_TEXTURES
    [material][a] property float4 jointToDecalTextureMapping;
#endif

#if TILED_DECAL_MASK && TILED_DECAL_ANIMATED_EMISSION
    [material][a] property float aniCamoPower = 1.0;
    [material][a] property float aniCamoSpeed = 1.0;
    [material][a] property float aniCamoAmplitude = 0.5;
    [material][a] property float aniCamoMiddle = 0.5;
    [material][a] property float aniCamoWidth = 0.1;
    [material][a] property float aniCamoSmooth = 0.3;
    [material][a] property float aniCamoWaveSpeed = 2.0;
    [material][a] property float aniCamoWaveLength = 1.0;
#endif

#define NEED_CHAIN_TEXCOORD_OFFSETS 1
#if INSTANCED_CHAIN
    #include "instanced-chain.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    #include "materials-vertex-processing.slh"

    float3 eyeCoordsPosition = mul(worldPosition, viewMatrix).xyz;
    float3 toLightDir32F = lightPosition0.xyz - eyeCoordsPosition * lightPosition0.w;
    half3 toLightDir = half3(toLightDir32F);

    half3 normal = half3(input.normal);
    half3 tangent = half3(input.tangent);
    half3 binormal = half3(input.binormal);

    #if INSTANCED_CHAIN
        normal.yz = half2(Rotate(float2(normal.yz), segmentDirection.y, segmentDirection.x));
        tangent.yz = half2(Rotate(float2(tangent.yz), segmentDirection.y, segmentDirection.x));
        binormal.yz = half2(Rotate(float2(binormal.yz), segmentDirection.y, segmentDirection.x));

        normal = normalize(normal);
        tangent = normalize(tangent);
        binormal = normalize(binormal);
    #endif

    #if SOFT_SKINNING
        float3x3 tbn = SoftSkinnedTBN(float3(tangent), float3(binormal), float3(normal), input.indices, input.weights);
        tangent = half3(tbn[0]);
        binormal = half3(tbn[1]);
        normal = half3(tbn[2]);
    #elif HARD_SKINNING
        float3x3 tbn = HardSkinnedTBN(float3(tangent), float3(binormal), float3(normal), input.index);
        tangent = half3(tbn[0]);
        binormal = half3(tbn[1]);
        normal = half3(tbn[2]);
    #endif

    half3 t = normalize(half3(mul(float4(float3(tangent), 0.0), worldViewInvTransposeMatrix).xyz));
    half3 b = normalize(half3(mul(float4(float3(binormal), 0.0), worldViewInvTransposeMatrix).xyz));
    half3 n = normalize(half3(mul(float4(float3(normal), 0.0), worldViewInvTransposeMatrix).xyz));

    // transform light and half angle vectors by tangent basis
    half3 toLightTangent;
    toLightTangent.x = dot(toLightDir, t);
    toLightTangent.y = dot(toLightDir, b);
    toLightTangent.z = dot(toLightDir, n);

    half3 toCameraDir = half3(-eyeCoordsPosition);
    half3 toCameraTangent;
    toCameraTangent.x = dot(toCameraDir, t);
    toCameraTangent.y = dot(toCameraDir, b);
    toCameraTangent.z = dot(toCameraDir, n);

    output.varToLightVec = half3(toLightTangent);

    t = normalize(half3(mul(float4(float3(tangent), 0.0), worldInvTransposeMatrix).xyz));
    b = normalize(half3(mul(float4(float3(binormal), 0.0), worldInvTransposeMatrix).xyz));
    n = normalize(half3(mul(float4(float3(normal), 0.0), worldInvTransposeMatrix).xyz));

    output.tangentToWorld0 = half3(t.x, b.x, n.x);
    output.tangentToWorld1 = half3(t.y, b.y, n.y);
    output.tangentToWorld2 = half3(t.z, b.z, n.z);

    #if USE_VERTEX_FOG
        #define FOG_eye_position cameraPosition
        #define FOG_view_position eyeCoordsPosition
        #define FOG_in_position input.position
        #define FOG_to_light_dir toLightDir32F // see MOBWOT-100926
        #define FOG_world_position worldPosition
        #include "vp-fog-math.slh"
        output.varFog = half4(FOG_result);
    #endif

    #if VERTEX_COLOR
        output.varVertexColor = half4(input.color0);
    #endif

    output.varTexCoord0.xy = input.texcoord0.xy;

    #if INSTANCED_CHAIN
        const float texCoordScale = segmentLength / chunkLength;
        const float texCoordOffset = GetTexCoordOffset(instanceId + 1);
        output.varTexCoord0.y = texCoordOffset + texCoordScale * output.varTexCoord0.y;
    #endif

    #if ALBEDO_TRANSFORM
        output.varTexCoord0.xy = ApplyTex0CoordsTransform(output.varTexCoord0.xy);
    #endif

    #if TEXTURE0_SHIFT_ENABLED
        output.varTexCoord0.xy += texture0Shift;
    #endif

    #if TEXTURE0_ANIMATION_SHIFT
        output.varTexCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
    #endif

    #if TILED_DECAL_MASK 
        float2 resDecalTexCoord = output.varTexCoord0.xy * decalTileCoordScale;
        #if TILED_DECAL_TRANSFORM
            #if HARD_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransformHardSkin(float2(resDecalTexCoord), input.index);
            #elif !SOFT_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransform(float2(resDecalTexCoord));
            #endif
        #endif
        output.varTexCoord0.zw = resDecalTexCoord;

        #if TILED_DECAL_ANIMATED_EMISSION
            half windowOffset = half(aniCamoAmplitude * sin(globalTime * aniCamoSpeed));
            output.aniCamoParams.x = half(aniCamoMiddle - 0.5 * aniCamoWidth + windowOffset - aniCamoSmooth);
            output.aniCamoParams.y = half(aniCamoMiddle + 0.5 * aniCamoWidth + windowOffset);
            output.aniCamoParams.z = half(1.0 / aniCamoSmooth);
            output.aniCamoParams.xy *= output.aniCamoParams.z;
            output.aniCamoParams.w = half(aniCamoPower * 0.5 * (1.0 + cos(input.position.y * aniCamoWaveLength + globalTime * aniCamoWaveSpeed)));
        #endif
    #endif

    #if PBR_LIGHTMAP
        output.varTexCoord1 = pbrUvScale * input.texcoord1.xy + pbrUvOffset;
    #elif PBR_DECAL
        output.varTexCoord1 = input.texcoord1.xy;
    #endif

    #if PBR_DETAIL
        output.varTexCoord2 = output.varTexCoord0.xy * pbrDetailTileCoordScale;
    #endif

    output.worldPos = worldPosition;

    #if RECEIVE_SHADOW
        float4 shadowViewPos = mul(worldPosition, shadowViewMatrix);
        output.shadowPos = shadowViewPos.xyz;
    #endif
    
    #if NEEDS_LOCAL_POSITION
        output.localPos.xyz = half3(localPosition);
        #if INSTANCED_CHAIN
            output.localPos.w = half(normal.z);
        #else
            output.localPos.w = half(input.normal.z);
        #endif
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        output.projPos = output.position;
    #endif

    #if MULTIPLE_DECAL_TEXTURES
        const int jointIndex = int(clamp(input.index, 0.0f, 3.0f));
        output.index = half(jointToDecalTextureMapping[jointIndex]);
    #endif

    return output;
}
