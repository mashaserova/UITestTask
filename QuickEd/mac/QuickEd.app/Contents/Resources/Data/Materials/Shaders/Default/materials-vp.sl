#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#if USE_VERTEX_FOG
    #include "vp-fog-props.slh"
#endif
#ensuredefined HIGHLIGHT_WAVE_ANIM 0

vertex_in
{
    float3 position : POSITION;

    #if MATERIAL_TEXTURE
        float2 texcoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || ALPHA_MASK || USE_VERTEX_DISPLACEMENT
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

    #if BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || RECEIVE_SHADOW || USE_VERTEX_DISPLACEMENT
        float3 normal : NORMAL;
    #endif
    
    #include "skinning-vertex-input.slh"
};

vertex_out
{
    float4 position : SV_POSITION;

    #if MATERIAL_TEXTURE || TILED_DECAL_MASK
        float2 varTexCoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD1;
    #endif

    #if ENVIRONMENT_MAPPING
        float4 reflectionVectorEnvMapMult : TEXCOORD4;
        [lowp] half4 varSpecularColor : TEXCOORD7;
    #endif

    #if MATERIAL_DETAIL
        float2 varDetailTexCoord : TEXCOORD2;
    #endif

    #if TILED_DECAL_MASK
        float2 varDecalTileTexCoord : TEXCOORD2;
    #endif

    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif

    #if FLOWMAP
        [lowp] float3 varFlowData : TEXCOORD6; // For flowmap animations - xy next frame uv. z - frame time
    #endif

    #if BLEND_BY_ANGLE || RECEIVE_SHADOW
        float3 worldSpaceNormal : TEXCOORD3;
    #endif
    #if BLEND_BY_ANGLE
        float3 worldSpaceView : TEXCOORD8;
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        float4 projectedPosition : COLOR3;
    #endif
    #if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
        float4 worldPos : COLOR2;
    #endif
    #if RECEIVE_SHADOW
        float NdotL : TANGENT;
        float3 shadowPos : COLOR5;
    #endif
};

#if ENVIRONMENT_MAPPING
    #include "fresnel-shlick.slh"
    [material][a] property float3 reflectionMetalFresnelReflectance = float3(0.5, 0.55, 0.3);
    [material][a] property float reflectionBrightenEnvMap = 2.8;
    [material][a] property float reflectionSpecular = 1.0;
#endif

#if USE_VERTEX_FOG || RECEIVE_SHADOW || ENVIRONMENT_MAPPING
    [auto][a] property float4x4 viewMatrix;
#endif

#if (USE_VERTEX_FOG && FOG_ATMOSPHERE) || ENVIRONMENT_MAPPING || RECEIVE_SHADOW
    [auto][a] property float4 lightPosition0;
#endif

#if BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || RECEIVE_SHADOW
    [auto][a] property float4x4 worldInvTransposeMatrix;
#endif

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE && !SETUP_LIGHTMAP
    [material][a] property float2 uvOffset = float2(0,0);
    [material][a] property float2 uvScale = float2(0,0);
#endif

#if MATERIAL_DETAIL
    [material][a] property float2 detailTileCoordScale = float2(1.0, 1.0);
#endif

#if TEXTURE0_SHIFT_ENABLED
    [material][a] property float2 texture0Shift = float2(0, 0);
#endif

#if TEXTURE0_ANIMATION_SHIFT
    [material][a] property float2 tex0ShiftPerSecond = float2(0, 0);
#endif

#if USE_VERTEX_FOG || BLEND_BY_ANGLE || ENVIRONMENT_MAPPING || (VERTEX_COLOR && DISTANCE_FADE_OUT)
    [auto][a] property float3 cameraPosition;
#endif

#if FLOWMAP
    [material][a] property float flowAnimSpeed = 0;
    [material][a] property float flowAnimOffset = 0;
#endif

#if RECEIVE_SHADOW || ENVIRONMENT_MAPPING
    [auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if VERTEX_COLOR && DISTANCE_FADE_OUT
    [material][a] property float2 distanceFadeNearFarSq;
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    #include "materials-vertex-processing.slh"

    #if FLOWMAP
        float flowSpeed = flowAnimSpeed;
        float flowOffset = flowAnimOffset;
        float scaledTime = globalTime * flowSpeed;
        float2 flowPhases = frac(float2(scaledTime, scaledTime+0.5))-float2(0.5, 0.5);
        float flowBlend = abs(flowPhases.x*2.0);
        output.varFlowData = float3(flowPhases * flowOffset, flowBlend);
    #elif PARTICLES_FLOWMAP_ANIMATION
        float flowOffset = input.texcoord2.w;
        output.varParticleFlowTexCoord = input.texcoord2.xy;
        output.varFlowData.xy = input.flowmapCrossfadeData.xy;
        output.varFlowData.z = flowOffset;
    #endif

    #if USE_VERTEX_FOG || RECEIVE_SHADOW || ENVIRONMENT_MAPPING
        float3 eyeCoordsPosition = mul(worldPosition, viewMatrix).xyz;
    #endif
    
    #if USE_VERTEX_FOG
        #define FOG_view_position eyeCoordsPosition
        #define FOG_to_light_dir lightPosition0.xyz
        #define FOG_eye_position cameraPosition
        #define FOG_in_position input.position
        #define FOG_world_position worldPosition
        #include "vp-fog-math.slh"
        output.varFog = half4(FOG_result);
    #endif

    #if BLEND_BY_ANGLE || RECEIVE_SHADOW || ENVIRONMENT_MAPPING
        float3 wsNormal = normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);
        #if BLEND_BY_ANGLE || RECEIVE_SHADOW
            output.worldSpaceNormal = wsNormal;
        #endif
    #endif
    #if BLEND_BY_ANGLE
        output.worldSpaceView = worldPosition.xyz - cameraPosition;
    #endif

    #if VERTEX_COLOR
        output.varVertexColor = half4(input.color0);
        #if DISTANCE_FADE_OUT
            half3 toCamera = half3(cameraPosition - worldPosition.xyz);
            half fadeOutAlpha = 1.0 - smoothstep(half(distanceFadeNearFarSq.x), half(distanceFadeNearFarSq.y), dot(toCamera, toCamera));
            output.varVertexColor.a *= fadeOutAlpha;
        #endif
    #endif

    #if MATERIAL_TEXTURE || TILED_DECAL_MASK || ENVIRONMENT_MAPPING
        output.varTexCoord0.xy = ApplyTex0CoordsTransform(input.texcoord0);
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

    #if TILED_DECAL_MASK
        float2 resDecalTexCoord = output.varTexCoord0.xy * decalTileCoordScale;
        #if TILED_DECAL_TRANSFORM
            #if HARD_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransformHardSkin(resDecalTexCoord, input.index);
            #elif !SOFT_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransform(resDecalTexCoord);
            #endif
        #endif
        output.varDecalTileTexCoord = resDecalTexCoord;
    #endif

    #if MATERIAL_DETAIL
        output.varDetailTexCoord = output.varTexCoord0.xy * detailTileCoordScale;
    #endif

    #if MATERIAL_DECAL || (MATERIAL_LIGHTMAP  && VIEW_DIFFUSE) || ALPHA_MASK
        #if MATERIAL_LIGHTMAP && VIEW_DIFFUSE && !SETUP_LIGHTMAP
            output.varTexCoord1 = uvScale*input.texcoord1.xy + uvOffset;
        #else
            output.varTexCoord1 = input.texcoord1.xy;
        #endif
    #endif

    #if FORCE_2D_MODE
        output.position.z = 0.0;
    #endif

    #if RECEIVE_SHADOW || ENVIRONMENT_MAPPING
        float3 normal = input.normal;
        #if SOFT_SKINNING
            normal = SoftSkinnedNormal(normal, input.indices, input.weights);
        #elif HARD_SKINNING
            normal = HardSkinnedNormal(normal, input.index);
        #endif

        float3 viewNormal = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);
        float3 toLightDir = normalize(lightPosition0.xyz - eyeCoordsPosition * lightPosition0.w);
        float NdotL = max(dot(viewNormal, toLightDir), 0.0);
    #endif
    
    #if ENVIRONMENT_MAPPING
        float3 toCameraNormalized = normalize(-eyeCoordsPosition);
        float3 H = normalize(toLightDir + toCameraNormalized);
        
        float NdotH = max(dot(viewNormal, H), 0.0);
        float LdotH = max(dot(toLightDir, H), 0.0);
        float NdotV = max(dot(viewNormal, toCameraNormalized), 0.0);

        float3 fresnelOut = FresnelShlickVec3(NdotV, reflectionMetalFresnelReflectance);

        output.varSpecularColor.xyz = half3(NdotL * reflectionSpecular * fresnelOut * (1.0 / LdotH * LdotH) );
        output.varSpecularColor.w = half(NdotH);
        float3 wsView = normalize(worldPosition.xyz - cameraPosition);
        output.reflectionVectorEnvMapMult.xyz = reflect(wsView, wsNormal);
        output.reflectionVectorEnvMapMult.w = (fresnelOut.x + fresnelOut.y + fresnelOut.z) * 0.33 * reflectionBrightenEnvMap;
    #endif

    #if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
        output.worldPos = worldPosition;
    #endif
    #if RECEIVE_SHADOW || LOD_TRANSITION
        output.projectedPosition = output.position;
    #endif
    #if RECEIVE_SHADOW
        output.NdotL = NdotL;
        float4 shadowViewPos = mul(worldPosition, shadowViewMatrix);
        output.shadowPos = shadowViewPos.xyz;
    #endif

    #if PUSH_TO_NEAR_PLANE_HACK
        // tank direction marker fix
        float z = output.position.z / output.position.w * ndcToZMappingScale + ndcToZMappingOffset;
        z *= 1e-4;
        output.position.z = (z - ndcToZMappingOffset) / ndcToZMappingScale * output.position.w;
    #endif

    return output;
}
