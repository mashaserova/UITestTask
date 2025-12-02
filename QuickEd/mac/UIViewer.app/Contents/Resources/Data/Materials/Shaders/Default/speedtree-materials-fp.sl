#include "common.slh"
#include "blending.slh"

#if !DRAW_DEPTH_ONLY
    #if PBR_SPEEDTREE
        #include "srgb.slh"
        #include "pbr-lighting.slh"
    #elif RECEIVE_SHADOW
        #include "shadow-mapping.slh"
    #endif
#endif

#if LOD_TRANSITION
    #include "lod-transition.slh"
#endif

fragment_in
{
    float2 varTexCoord0 : TEXCOORD0;
    [lowp] half4 varVertexColor : COLOR1;

    #if LOD_TRANSITION || (RECEIVE_SHADOW && !DRAW_DEPTH_ONLY)
        float4 projectedPosition : COLOR3;
    #endif

#if !DRAW_DEPTH_ONLY
    #if PBR_SPEEDTREE
        float4 worldPos : COLOR2;
    #endif

    #if RECEIVE_SHADOW
        float4 worldPosShadow : TEXCOORD1;
        float3 shadowPos : COLOR5;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif
    #if PBR_SPEEDTREE
        half3 tangentToWorld0 : TANGENTTOWORLD0;
        half3 tangentToWorld1 : TANGENTTOWORLD1;
        half3 tangentToWorld2 : TANGENTTOWORLD2;
    #endif
#endif
};

fragment_out
{
    half4 color : SV_TARGET0;
};

#if PBR_SPEEDTREE
    [auto][a] property float4x4 invViewMatrix;

    [auto][a] property float3 lightColor0;
    [auto][a] property float4 lightPosition0;
    [auto][a] property float lightIntensity0;
    
    [auto][a] property float3 cameraPosition;
    
    uniform sampler2D baseColorMap; // RGB - albedo color (SRGB), A - alpha
    uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
    uniform sampler2D roughnessAOMap; // RG or AG(DXT5NM) or GA(ASTC) - roughness / ambient occlusion

    [material][a] property float normalScale = 1.0;
    [material][a] property float metallness = 0.0;
    [material][a] property float2 pbrTextureAOBrightnessContrast = float2(0.0f, 1.0f);
    [material][a] property float pbrShadowLighten = 0.0f;
#else
    uniform sampler2D albedo;
#endif

#if ALPHATEST && ALPHATESTVALUE
    [material][a] property float alphatestThreshold = 0.0;
#endif

#if ALPHASTEPVALUE && ALPHABLEND
    [material][a] property float alphaStepValue = 0.5;
#endif

#if FLATCOLOR || FLATALBEDO
    [material][a] property float4 flatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

#if DEBUG_UNLIT
    [material][a] property float4 debugFlatColor = float4(1.0, 0.0, 1.0, 1.0);
#endif

#if LOD_TRANSITION
    [material][a] property float lodTransitionThreshold = 0.0;
#endif

#if PBR_SPEEDTREE
    #if GLOBAL_PBR_TINT
        #if !IGNORE_BASE_COLOR_PBR_TINT
            [material][a] property float3 speedTreeBaseColorPbrTint = float3(0.5, 0.5, 0.5);
        #endif
        #if !IGNORE_ROUGHNESS_PBR_TINT
            [material][a] property float speedTreeRoughnessPbrTint = 0.5;
        #endif
    #endif
#else
    #if !IGNORE_GLOBAL_FLAT_COLOR && GLOBAL_TINT
        [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
    #endif
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = input.varTexCoord0.xy;

    #if PBR_SPEEDTREE
        half4 baseColor = half4(tex2D(baseColorMap, texCoord)); // SRGB
    #else
        half4 baseColor = half4(tex2D(albedo, texCoord));
    #endif

    #if !ALPHATEST && !ALPHABLEND
        #if TEST_OCCLUSION
            baseColor.rgb = baseColor.rgb * baseColor.a;
        #endif
        baseColor.a = half(1.0);
    #endif

    #if FLATALBEDO
        baseColor *= half4(flatColor);
    #endif

    #if LOD_TRANSITION
        float2 xyNDC = input.projectedPosition.xy / input.projectedPosition.w;
        baseColor.a *= CalculateLodTransitionAlpha(xyNDC, half(lodTransitionThreshold));
    #endif

    #if ALPHATEST && (DRAW_DEPTH_ONLY || (!VIEW_MODE_OVERDRAW_HEAT && !DEBUG_UNLIT))
        half alpha = baseColor.a * input.varVertexColor.a;
        #if ALPHATESTVALUE
            if(alpha < half(alphatestThreshold)) discard;
        #else
            if(alpha < half(0.5)) discard;
        #endif
    #endif
    
#if DRAW_DEPTH_ONLY
    output.color = half4(1.0, 1.0, 1.0, 1.0);
#else
    #if ALPHASTEPVALUE && ALPHABLEND
        baseColor.a = step(half(alphaStepValue), baseColor.a);
    #endif

    // DRAW PHASE
    #if !ALPHABLEND
        baseColor.a = half(1.0);
    #endif

#if !PBR_SPEEDTREE
    baseColor *= input.varVertexColor;
#endif

    #if FLATCOLOR
        baseColor *= half4(flatColor);
    #endif

    #if PBR_SPEEDTREE
        half2 roughnessAO = half2(FP_SWIZZLE(tex2D(roughnessAOMap, texCoord)));

        half3 tangentNormal = half3(half2(FP_SWIZZLE(tex2D(baseNormalMap, texCoord))), half(1.0));
        tangentNormal.xy = tangentNormal.xy * 2.0 - 1.0;
        tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
        tangentNormal.xy *= normalScale;

        half3 polygonN = normalize(half3(input.tangentToWorld0.z, input.tangentToWorld1.z, input.tangentToWorld2.z));
        
        half3 N = normalize(half3(
            dot(tangentNormal, input.tangentToWorld0),
            dot(tangentNormal, input.tangentToWorld1),
            dot(tangentNormal, input.tangentToWorld2)));
        half3 V = half3(normalize(cameraPosition - input.worldPos.xyz));
        
        half3 L = half3(lightPosition0.xyz);
        L = half3(mul(float4(float3(L.xyz), 0.0), invViewMatrix).xyz);
        
        half occlusionTexCorrected = saturate(half(pbrTextureAOBrightnessContrast.y) * (roughnessAO.g - half(0.5)) + half(0.5f + pbrTextureAOBrightnessContrast.x));
        half occlusion = dot(input.varVertexColor.rgb, half3(0.33, 0.33, 0.33)) * occlusionTexCorrected; // ignoring color from SH

        #if RECEIVE_SHADOW
            half4 shadowMapInfo;
            shadowMapInfo = getCascadedShadow(input.worldPosShadow, input.shadowPos, half4(input.projectedPosition), half3(0.0, 1.0, 0.0), 0.5);
            half shadowTerm = half(lerp(shadowMapInfo.x, half(1.0), half(pbrShadowLighten)));
        #else
            half shadowTerm = half(1.0);
        #endif
        
        half3 emissiveUnused = half3(0.0, 0.0, 0.0);
        
        #if GLOBAL_PBR_TINT
            #if !IGNORE_BASE_COLOR_PBR_TINT
                baseColor.rgb *= half3(speedTreeBaseColorPbrTint) * half(2.0);
            #endif
            #if !IGNORE_ROUGHNESS_PBR_TINT
                roughnessAO.x *= half(speedTreeRoughnessPbrTint) * half(2.0);
            #endif
        #endif
        
        // saturate for energy conservation
        baseColor = saturate(baseColor);
        roughnessAO = saturate(roughnessAO);

        output.color.rgb = getPBR(polygonN, N, V, L, half3(lightColor0), half(lightIntensity0), baseColor.rgb, half(metallness), roughnessAO.x, occlusion, shadowTerm, emissiveUnused);
        output.color = half4(LinearToSRGB(output.color.r), LinearToSRGB(output.color.g), LinearToSRGB(output.color.b), baseColor.a);
    #else
        #if !IGNORE_GLOBAL_FLAT_COLOR && GLOBAL_TINT
            baseColor.rgb *= half3(globalFlatColor.rgb) * half(2.0);
        #endif

        #if RECEIVE_SHADOW
            half4 shadowMapInfo;
            shadowMapInfo = getCascadedShadow(input.worldPosShadow, input.shadowPos, half4(input.projectedPosition), half3(0.0, 1.0, 0.0), 0.5);
    
            half3 shadowMapColor;
            shadowMapColor = getShadowColor(shadowMapInfo);
            baseColor.rgb *= shadowMapColor;
        #endif
        output.color = baseColor;
    #endif

    #if USE_VERTEX_FOG
        half varFogAmoung = input.varFog.a;
        half3 varFogColor = input.varFog.rgb;
        output.color.rgb = lerp(output.color.rgb, varFogColor, varFogAmoung);
    #endif

    #if PBR_SPEEDTREE // debug draw
        #if VIEW_ALBEDO && !VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
            output.color.rgb = half3(LinearToSRGB(baseColor.r), LinearToSRGB(baseColor.g), LinearToSRGB(baseColor.b));
        #endif

        #if VIEW_ALL
            #if VIEW_NORMAL
                output.color.rgb = half3(tangentNormal.xyz * half(0.5) + half(0.5));
            #endif
            
            #if VIEW_NORMAL_FINAL
                output.color.rgb = half3(N.xyz * half(0.5) + half(0.5));
            #endif

            #if VIEW_ROUGHNESS
                output.color.rgb = half3(roughnessAO.xxx);
            #endif

            #if VIEW_METALLIC
                output.color.rgb = half3(metallness, metallness, metallness);
            #endif

            #if VIEW_AMBIENTOCCLUSION
                output.color.rgb = half3(occlusion, occlusion, occlusion);
            #endif
        #endif
    #endif    
#endif
    #include "debug-modify-color-half.slh"
    return output;
}
