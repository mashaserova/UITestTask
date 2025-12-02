#include "common.slh"
#ensuredefined VEGETATION_LIT 0
#define USE_VEGETATION_LIT (VEGETATION_LIT && !DRAW_DEPTH_ONLY)

#if USE_VEGETATION_LIT
    #include "lighting.slh"
    #include "fresnel-shlick.slh"
#endif

#if DRAW_DEPTH_ONLY
    #include "depth-only-fragment-shader.slh"
#else

#if USE_SHADOW_MAP
    #include "shadow-mapping.slh"
#endif

fragment_in
{
    #if USE_SHADOW_MAP
        float4 projectedPosition : TEXCOORD0;
    #endif

    float2 texCoord : TEXCOORD1;
    [lowp] half3 vegetationColor : COLOR0;
    #if USE_VERTEX_FOG
        float4 varFog : TEXCOORD5;
    #endif
    #if USE_SHADOW_MAP
        float4 varWorldPos : COLOR1;

        float3 shadowPos : COLOR5;
    #endif
    
    #if USE_VEGETATION_LIT
        float3 varToLightVec : TEXCOORD2;
        float3 varToCameraVec : TEXCOORD3;
    #endif
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D albedo;
#if USE_VEGETATION_LIT
    uniform sampler2D normalmap;
    [auto][a] property float3 lightColor0;
    
    [material][a] property float inGlossiness = 0.5;
    [material][a] property float inSpecularity = 1.0;
    [material][a] property float3 metalFresnelReflectance = float3(0.5, 0.5, 0.5);
    [material][a] property float normalScale = 1.0;
#endif

[material][a] property float grassBaseColorMult = 2.0;
[material][a] property float2 grassShadowDiffuseSpecMult = float2(0.5, 0.5);

#if DEBUG_UNLIT
    [material][a] property float4 debugFlatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float4 textureColor0 = tex2D(albedo, input.texCoord);
    #if USE_SHADOW_MAP
        half4 shadowInfo;
        shadowInfo = getCascadedShadow(input.varWorldPos, input.shadowPos, half4(input.projectedPosition), half3(0.0, 0.0, 1.0), 1.0);
        half3 shadowColor;
        shadowColor = getShadowColor(shadowInfo);
    #endif
    
    #if USE_VEGETATION_LIT
        float3 normal = tex2D(normalmap, input.texCoord).rgb * 2.0 - 1.0;
        normal.xy *= normalScale;
        normal = normalize(normal);
        
        float3 toLightNormalized = normalize(input.varToLightVec);
        float3 toCameraNormalized = normalize(input.varToCameraVec);

        float NdotL = max(dot(normal, toLightNormalized), 0.0);
        float3 diffuse = lightColor0 * (NdotL / _PI);
        
        float3 H = normalize(toCameraNormalized + toLightNormalized);
        float NdotH = max(dot(normal, H), 0.0);
        float NdotV = max(dot(normal, toCameraNormalized), 0.0);
        
        float specularTerm = BlinnPhong(NdotH, inGlossiness * textureColor0.a, NdotL * inSpecularity);
        float fresnelOut = FresnelShlick(NdotV, (metalFresnelReflectance.r + metalFresnelReflectance.g + metalFresnelReflectance.b) / 3.0);
        float3 specular = lightColor0 * specularTerm * fresnelOut;

        #if USE_SHADOW_MAP
            float diffuseShadowedTerm = grassShadowDiffuseSpecMult.x + (1.0 - grassShadowDiffuseSpecMult.x) * shadowInfo.x;
            float specularShadowedTerm = grassShadowDiffuseSpecMult.y + (1.0 - grassShadowDiffuseSpecMult.y) * shadowInfo.x;
            float3 color = textureColor0.rgb * float3(input.vegetationColor) * grassBaseColorMult * float3(shadowColor) + diffuse * diffuseShadowedTerm + specular * specularShadowedTerm;
        #else
            float3 color = textureColor0.rgb * float3(input.vegetationColor) * grassBaseColorMult + diffuse + specular;
        #endif
    #else
        float3 color = textureColor0.rgb * float3(input.vegetationColor) * grassBaseColorMult;
        #if USE_SHADOW_MAP
            color.rgb *= float3(shadowColor);
        #endif
    #endif

    #if USE_VERTEX_FOG
        float varFogAmoung = input.varFog.a;
        float3 varFogColor = input.varFog.rgb;
        color = lerp(color, varFogColor, varFogAmoung);
    #endif
    output.color = float4(color, 1.0);
    
    #include "debug-modify-color.slh"
    return output;
}
#endif
