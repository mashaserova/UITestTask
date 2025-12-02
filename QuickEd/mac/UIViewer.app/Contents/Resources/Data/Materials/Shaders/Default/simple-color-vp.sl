#include "common.slh"
#include "materials-vertex-properties.slh"

#include "lighting.slh"
#include "vp-fog-props.slh"
#include "fresnel-shlick.slh"

#ensuredefined SIMPLE_COLOR_RECEIVED_SHADOW_ONLY 0
#ensuredefined NEED_CHAIN_TEXCOORD_OFFSETS 0

#define SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED (SIMPLE_COLOR_RECEIVED_SHADOW_ONLY && USE_SHADOW_MAP)

vertex_in
{
    float3 position : POSITION;
    #if !DEBUG_UNLIT || SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED || USE_VERTEX_DISPLACEMENT
        float3 normal : NORMAL;
    #endif
    
    #if USE_VERTEX_DISPLACEMENT
        float2 texcoord1 : TEXCOORD1;
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
#if !DEBUG_UNLIT || SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
    float4 varColor : COLOR0;
#endif
   
#if USE_VERTEX_FOG
    [lowp] half4 varFog : TEXCOORD5;
#endif

#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
    float4 worldPos : COLOR2;
    float4 projectedPosition : COLOR3;
    float3 worldSpaceNormal : TEXCOORD3;
    float NdotL : TANGENT;
    float3 shadowPos : COLOR5;
#endif
};

[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

#if !DEBUG_UNLIT || SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
    [material][a] property float4 debugFlatColor = float4(1.0, 0.0, 1.0, 1.0);
#endif

#if FLATCOLOR
    [material][a] property float4 flatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

#if USE_VERTEX_FOG
    [auto][a] property float3 cameraPosition;
#endif
#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
    [auto][a] property float4x4 worldInvTransposeMatrix;
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if INSTANCED_CHAIN
    #include "instanced-chain.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    #include "materials-vertex-processing.slh"
    
    #if !DEBUG_UNLIT || USE_VERTEX_FOG || SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
        const float3 eyeCoordsPosition = mul(worldPosition, viewMatrix).xyz;
        const float3 toLightDir = normalize(-eyeCoordsPosition); // light goes from camera
    #endif
    
    #if !DEBUG_UNLIT || SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
        #if FLATCOLOR
            float4 tintColor = flatColor;
        #else
            float4 tintColor = debugFlatColor;
        #endif

        const float specularShininess = 4.0f;
        const float specularSample = 0.15f;
        const float3 ambientLightColor = float3(0.4f, 0.4f, 0.4f);
        const float3 lightColor = float3(0.25f, 0.25f, 0.25f) + 0.5f * tintColor.rgb;

        const float3 eyeCoordsNormal = normalize(mul(float4(input.normal, 0.0), worldViewInvTransposeMatrix).xyz);
        
        const float NdotL = max(0.0, dot(eyeCoordsNormal, toLightDir));

        float3 diffuseColor = NdotL * lightColor;

        float3 toCameraDir = normalize(-eyeCoordsPosition);
        float3 H = normalize(toLightDir + toCameraDir);
        float nDotHV = max(0.0, dot(eyeCoordsNormal, H));
        float specTerm = pow(nDotHV, specularShininess);
        float3 specularColor = specTerm * specularSample * lightColor;

        output.varColor.rgb = ambientLightColor * tintColor.rgb + diffuseColor + specularColor;
        output.varColor.a = tintColor.a;
    #endif

    #if USE_VERTEX_FOG
        #define FOG_eye_position cameraPosition
        #define FOG_view_position eyeCoordsPosition
        #define FOG_in_position input.position
        #define FOG_to_light_dir toLightDir
        #define FOG_world_position worldPosition
        #include "vp-fog-math.slh"
        output.varFog = half4(FOG_result);
    #endif

    #if FORCE_2D_MODE
        output.position.z = 0.0;
    #endif

    #if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
        output.worldPos = worldPosition;
        output.NdotL = NdotL;
        output.projectedPosition = output.position;
        output.worldSpaceNormal = normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);

        float4 shadowViewPos = mul(worldPosition, shadowViewMatrix);
        output.shadowPos = shadowViewPos.xyz;
    #endif

    return output;
}
