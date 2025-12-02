#include "common.slh"
#include "blending.slh"
#if ENVIRONMENT_MAPPING
    #include "lighting.slh"
#endif
#if RECEIVE_SHADOW
    #include "shadow-mapping.slh"
#endif
#if SETUP_LIGHTMAP
    #include "setup-lightmap.slh"
#endif
#include "highlight-animation.slh"
#if LOD_TRANSITION
    #include "lod-transition.slh"
#endif

fragment_in
{
    #if MATERIAL_TEXTURE || TILED_DECAL_MASK || ENVIRONMENT_MAPPING
        float2 varTexCoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || (MATERIAL_LIGHTMAP  && VIEW_DIFFUSE) || ALPHA_MASK
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
        float3 varFlowData : TEXCOORD6;
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

fragment_out
{
    float4 color : SV_TARGET0;
};

#if MATERIAL_TEXTURE
    uniform sampler2D albedo;
#endif

#if ENVIRONMENT_MAPPING
    uniform sampler2D envReflectionMask;
    uniform samplerCUBE cubemap;
    [material][a] property float3 cubemapIntensity = float3(1.0, 1.0, 1.0);
    [material][a] property float reflectionLerpEnvMap = 0.5;
    [material][a] property float reflectionSpecParamGloss = 0.45;
    [material][a] property float reflectionAddDiffuse = 0.0;
    [material][a] property float reflectionMaskMultiplier = 100.0;
    [material][a] property float reflectionMultLightmap = 2.0;
    [auto][a] property float3 lightColor0;
#endif

#if MATERIAL_DECAL
    uniform sampler2D decal;
#endif

#if ALPHA_MASK
    uniform sampler2D alphamask;
#endif

#if MATERIAL_DETAIL
    uniform sampler2D detail;
#endif

#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
    uniform sampler2D lightmap;
#endif

#if FLOWMAP
    uniform sampler2D flowmap;
#endif

#if MATERIAL_TEXTURE && ALPHATEST && ALPHATESTVALUE
    [material][a] property float alphatestThreshold = 0.0;
#endif

#if MATERIAL_TEXTURE && ALPHASTEPVALUE && ALPHABLEND
    [material][a] property float alphaStepValue = 0.5;
#endif

#if TILED_DECAL_MASK
    uniform sampler2D decalmask;
    uniform sampler2D decaltexture;
    [material][a] property float4 decalTileColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

#if FLATCOLOR || FLATALBEDO
    [material][a] property float4 flatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

#if SETUP_LIGHTMAP && (MATERIAL_DECAL || MATERIAL_LIGHTMAP)
    [material][a] property float lightmapSize = 1.0;
#endif

#if BLEND_BY_ANGLE
    [material][a] property float2 angleBlendBounds = float2(0.0, 1.0);
    [material][a] property float angleBlendPower = 1.0;
    [material][a] property float angleBlendInversion = 0.0;
#endif

#if LOD_TRANSITION
    [material][a] property float lodTransitionThreshold = 0.0;
#endif

#if GLOBAL_TINT
    #if !IGNORE_GLOBAL_FLAT_COLOR
        [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
    #endif
    #if !IGNORE_LIGHTMAP_ADJUSTMENT && (MATERIAL_DECAL || MATERIAL_LIGHTMAP)
        [material][a] property float3 materialLightmapAdjustment = float3(0.0, 1.0, 1.0);
    #endif
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    // FETCH PHASE
    half4 textureColor0 = half4(1.0, 0.0, 0.0, 1.0);

    #if MATERIAL_TEXTURE
        #if ALPHATEST || ALPHABLEND
            #if FLOWMAP
                float2 flowtc = input.varTexCoord0.xy;
                float3 flowData = input.varFlowData;
                float2 flowDir = float2(tex2D(flowmap, flowtc).xy) * 2.0 - 1.0;
                half4 flowSample1 = half4(tex2D(albedo, input.varTexCoord0.xy + flowDir*flowData.x));
                half4 flowSample2 = half4(tex2D(albedo, input.varTexCoord0.xy + flowDir*flowData.y));
                textureColor0 = lerp(flowSample1, flowSample2, half(flowData.z));
            #else
                textureColor0 = half4(tex2D(albedo, input.varTexCoord0.xy));
            #endif

            #if ALPHA_MASK
                textureColor0.a *= FP_A8(tex2D(alphamask, input.varTexCoord1));
            #endif

          #else
            #if FLOWMAP
                float2 flowtc = input.varTexCoord0;
                float3 flowData = input.varFlowData;
                float2 flowDir = float2(tex2D(flowmap, flowtc).xy) * 2.0 - 1.0;
                half3 flowSample1 = half3(tex2D(albedo, input.varTexCoord0 + flowDir*flowData.x).rgb);
                half3 flowSample2 = half3(tex2D(albedo, input.varTexCoord0 + flowDir*flowData.y).rgb);
                textureColor0.xyz = lerp(flowSample1, flowSample2, half(flowData.z));
                textureColor0.w = 1.0;
            #else
                #if TEST_OCCLUSION
                    half4 preColor = half4(tex2D(albedo, input.varTexCoord0));
                    textureColor0.rgb = half3(preColor.rgb * preColor.a);
                #else
                    textureColor0.rgb = half3(tex2D(albedo, input.varTexCoord0).rgb);
                #endif
            #endif
        #endif
    #endif

    #if FLATALBEDO
        textureColor0 *= half4(flatColor);
    #endif

    #if LOD_TRANSITION
        float2 xyNDC = input.projectedPosition.xy / input.projectedPosition.w;
        textureColor0.a *= CalculateLodTransitionAlpha(xyNDC, half(lodTransitionThreshold));
    #endif

    #if MATERIAL_TEXTURE || LOD_TRANSITION
        #if ALPHATEST && !VIEW_MODE_OVERDRAW_HEAT
            float alpha = textureColor0.a;
            #if VERTEX_COLOR
                alpha *= float(input.varVertexColor.a);
            #endif
            #if ALPHATESTVALUE
                if( alpha < alphatestThreshold ) discard;
            #else
                if( alpha < 0.5 ) discard;
            #endif
        #endif

        #if ALPHASTEPVALUE && ALPHABLEND
            textureColor0.a = half(step(alphaStepValue, float(textureColor0.a)));
        #endif
    #endif

    #if (MATERIAL_DECAL || MATERIAL_LIGHTMAP) && VIEW_DIFFUSE
    
        half3 textureColor1 = 1.0;

        #if !IGNORE_LIGHTMAP_ADJUSTMENT && GLOBAL_TINT
            half lightmapBrightness = half(materialLightmapAdjustment.r);
            half lightmapContrast = half(materialLightmapAdjustment.g);
            half lightmapGamma = half(materialLightmapAdjustment.b);
        #endif

        #if MATERIAL_DECAL
            half4 decalTextureFetch = half4(tex2D( decal, input.varTexCoord1 ));

            #if !IGNORE_LIGHTMAP_ADJUSTMENT && GLOBAL_TINT
                decalTextureFetch.rgb = pow(decalTextureFetch.rgb, lightmapGamma);
                decalTextureFetch.rgb = (decalTextureFetch.rgb - half(0.5)) * lightmapContrast + half(0.5);
                decalTextureFetch.rgb += lightmapBrightness;
            #endif

            textureColor1 *= decalTextureFetch.rgb;
        #endif

        #if MATERIAL_LIGHTMAP
            half3 lightmapTextureColor = half3(tex2D( lightmap, input.varTexCoord1 ).rgb);

            #if !IGNORE_LIGHTMAP_ADJUSTMENT && GLOBAL_TINT
                lightmapTextureColor.rgb = pow(lightmapTextureColor.rgb, lightmapGamma);
                lightmapTextureColor.rgb = (lightmapTextureColor.rgb - half(0.5)) * lightmapContrast + half(0.5);
                lightmapTextureColor.rgb += lightmapBrightness;
            #endif
            
            textureColor1 *= lightmapTextureColor.rgb;
        #endif

        #if SETUP_LIGHTMAP
            textureColor1 = SetupLightmap(input.varTexCoord1, lightmapSize);
        #endif

    #endif

    #if MATERIAL_DETAIL
        half3 detailTextureColor = half3(tex2D( detail, input.varDetailTexCoord ).rgb);
    #endif

    // DRAW PHASE

    #if MATERIAL_DECAL || MATERIAL_LIGHTMAP
        half3 color = half3(0.0, 0.0, 0.0);

        #if VIEW_ALBEDO
            color = half3(textureColor0.rgb);
        #else
            color = half3(1.0, 1.0, 1.0);
        #endif

        #if VIEW_DIFFUSE
            half3 shadowColor = half3(textureColor1.rgb);
            #if RECEIVE_SHADOW
                half4 shadowMapInfo;
                half3 shadowMapColor;
                shadowMapInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(input.worldSpaceNormal), half(input.NdotL));
                #if (MATERIAL_DECAL && LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL)
                    float lmLighteningMult = lerp(shadowLMGateFactor.w, 1.0, saturate(decalTextureFetch.a * shadowLMGateFactor.z));
                    shadowMapColor = getShadowColorMultLM(shadowMapInfo, half(lmLighteningMult)) * half(decalTextureFetch.a);
                #else
                    float lmBrightness = (shadowColor.x + shadowColor.y + shadowColor.z) * 0.33f;
                    float lmLighteningMult = lerp(shadowLMGateFactor.y, 1.0, saturate(lmBrightness * shadowLMGateFactor.x));
                    shadowMapColor = getShadowColorMultLM(shadowMapInfo, half(lmLighteningMult));
                #endif
                shadowColor *= shadowMapColor;
            #elif (MATERIAL_DECAL && LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL)
                // objects colored with landscape (a_bazylchik request)
                shadowColor *= decalTextureFetch.a;
            #endif
            
            #if VIEW_ALBEDO
                color *= shadowColor * 2.0;
            #else
                //do not scale lightmap in view diffuse only case. artist request
                color *= shadowColor;
            #endif
        #endif

    #elif MATERIAL_TEXTURE
        half3 color = half3(textureColor0.rgb);
        #if RECEIVE_SHADOW
            half4 shadowMapInfo;
            half3 shadowMapColor;
            shadowMapInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(input.worldSpaceNormal), half(input.NdotL));
            shadowMapColor = getShadowColor(shadowMapInfo);
            color *= shadowMapColor;
        #endif
    #else
        half3 color = half3(1.0, 1.0, 1.0);
    #endif

    #if ENVIRONMENT_MAPPING
        float envMaskValue = FP_A8(tex2D(envReflectionMask, input.varTexCoord0));
        half maskScaled = half(min(envMaskValue * reflectionMaskMultiplier, 1.0));

        #if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
            half3 lightenLM = saturate(textureColor1 * reflectionMultLightmap);
        #else
            half3 lightenLM = half3(reflectionMultLightmap, reflectionMultLightmap, reflectionMultLightmap);
        #endif

        float specularTerm;
        specularTerm = BlinnPhong(float(input.varSpecularColor.w), reflectionSpecParamGloss * envMaskValue, 1.0);

        half3 specular = half3(specularTerm * lightColor0) * input.varSpecularColor.xyz;
        half3 specularEnvReflection = half3(texCUBE(cubemap, input.reflectionVectorEnvMapMult.xyz).xyz * cubemapIntensity
          * input.reflectionVectorEnvMapMult.w) * lightenLM * maskScaled;

        color = lerp(color, color * half(reflectionAddDiffuse) + specularEnvReflection, half(min(half(envMaskValue) * reflectionLerpEnvMap, 1.0)))
         + specular * maskScaled;
    #endif

    #if TILED_DECAL_MASK
        half maskSample = FP_A8(tex2D(decalmask, input.varTexCoord0));
        half4 tileColor = half4(tex2D(decaltexture, input.varDecalTileTexCoord).rgba * decalTileColor);
        color.rgb += (tileColor.rgb - color.rgb) * tileColor.a * maskSample;
    #endif

    #if MATERIAL_DETAIL
        color *= detailTextureColor.rgb * 2.0;
    #endif

    #if ALPHABLEND && MATERIAL_TEXTURE
        float4 outColor = float4(float3(color.rgb), textureColor0.a);
    #else
        float4 outColor = float4(float3(color.rgb), 1.0);
    #endif

    #if VERTEX_COLOR
        outColor *= float4(input.varVertexColor);
    #endif

    #if !IGNORE_GLOBAL_FLAT_COLOR && GLOBAL_TINT
        outColor.rgb *= globalFlatColor.rgb * 2.0;
    #endif

    #if FLATCOLOR
        outColor *= flatColor;
    #endif
    #if HIGHLIGHT_COLOR || HIGHLIGHT_WAVE_ANIM
        outColor = ApplyHighlightAnimation(outColor, input.worldPos.z);
    #endif

    #if USE_VERTEX_FOG
        float varFogAmoung = float(input.varFog.a);
        float3 varFogColor = float3(input.varFog.rgb);
        outColor.rgb = lerp(outColor.rgb, varFogColor, varFogAmoung);
    #endif

    #if BLEND_BY_ANGLE
        float VdotN = abs(dot(input.worldSpaceView, input.worldSpaceNormal)) / (length(input.worldSpaceView) * length(input.worldSpaceNormal));
        VdotN = lerp(VdotN, 1.0 - VdotN, angleBlendInversion);
        float angleBlendValue = saturate((VdotN - angleBlendBounds.x) / (angleBlendBounds.y - angleBlendBounds.x));
        outColor.w *= pow(angleBlendValue, angleBlendPower);
    #endif
    
    output.color = outColor;
    
    #include "debug-modify-color.slh"
    return output;
}
