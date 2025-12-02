#include "common.slh"
#include "blending.slh"

#ensuredefined FLORA_LOD_TRANSITION_NEAR 0
#ensuredefined FLORA_LOD_TRANSITION_FAR 0
#ensuredefined FLORA_AMBIENT_ANIMATION 0
#ensuredefined FLORA_WIND_ANIMATION 0
#ensuredefined FLORA_PBR_LIGHTING 0
#ensuredefined FLORA_NORMAL_MAP 0
#ensuredefined FLORA_EDGE_MAP 0
#ensuredefined FLORA_FAKE_SHADOW 0
#ensuredefined FLORA_LAYING 0

#define FLORA_LOD_TRANSITION (FLORA_LOD_TRANSITION_NEAR || FLORA_LOD_TRANSITION_FAR)
#define FLORA_ANIMATION (FLORA_AMBIENT_ANIMATION || FLORA_WIND_ANIMATION)

#if FLORA_LOD_TRANSITION
    #include "lod-transition.slh"
#endif

#if !DRAW_DEPTH_ONLY
    #if FLORA_PBR_LIGHTING
        #include "srgb.slh"
        #include "pbr-lighting.slh"
    #elif RECEIVE_SHADOW
        #include "shadow-mapping.slh"
    #endif
#endif

fragment_in
{
    [lowp] half2 texCoord : TEXCOORD0;
    #if DRAW_DEPTH_ONLY
        float4 projPos : TEXCOORD2;
        #if FLORA_LOD_TRANSITION
            float3 worldPos : TEXCOORD3;
        #endif 
    #else
        #if FLORA_LAYING
            [lowp] half3 uvColor : COLOR1; // .z - layingStrength
        #else
            [lowp] half2 uvColor : COLOR1;
        #endif
        #if USE_VERTEX_FOG
            [lowp] half4 varFog : TEXCOORD1;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION
            float4 projPos : TEXCOORD2;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION || FLORA_PBR_LIGHTING
            float3 worldPos : TEXCOORD3;
        #endif
        #if RECEIVE_SHADOW
            float3 shadowPos : COLOR5;
        #endif
        #if FLORA_PBR_LIGHTING
            #if FLORA_NORMAL_MAP
                half4 tangentToWorld0 : TANGENTTOWORLD0; // .w - localHeight
                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    half4 tangentToWorld1 : TANGENTTOWORLD1; // .w - animation.x
                    half4 tangentToWorld2 : TANGENTTOWORLD2; // .w - animation.y
                #else
                    half3 tangentToWorld1 : TANGENTTOWORLD1;
                    half3 tangentToWorld2 : TANGENTTOWORLD2;
                #endif
            #else
                half4 normal : NORMAL; // .w - localHeight
                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    half2 animation : TEXCOORD4;
                #endif
            #endif
        #endif
    #endif
};

fragment_out
{
    half4 color : SV_TARGET0;
};

#if FLORA_PBR_LIGHTING
    uniform sampler2D baseColorMap;
#else
    uniform sampler2D albedo;
#endif

#if !DRAW_DEPTH_ONLY
    #if FLORA_PBR_LIGHTING
        uniform sampler2D floraPbrColorMap;
    #else
        uniform sampler2D floraColorMap;
    #endif
    #if FLORA_LAYING
        #if FLORA_PBR_LIGHTING
            [material][a] property float3 floraLayingPbrColorFactor;
        #else
            [material][a] property float3 floraLayingColorFactor;
        #endif
    #endif
    #if FLORA_PBR_LIGHTING
        #if GLOBAL_PBR_TINT
            [material][a] property float3 floraBaseColorPbrTint = float3(0.5, 0.5, 0.5);
            [material][a] property float floraRoughnessPbrTint = 0.5;
        #endif
    #else
        #if GLOBAL_TINT
            [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
            [material][a] property float3 floraLightmapAdjustment = float3(0.0, 1.0, 1.0);
        #endif
    #endif
#endif

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
    #if FLORA_NORMAL_MAP
        uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
    #endif

    uniform sampler2D floraLightmap;
    #if FLORA_EDGE_MAP
        uniform sampler2D floraEdgeMap;
    #endif
    
    [material][a] property float3 worldSize;

    [auto][a] property float4x4 invViewMatrix;

    [auto][a] property float3 lightColor0;

    [auto][a] property float4 lightPosition0;

    [auto][a] property float4x4 invProjMatrix;
    [auto][a] property float4x4 viewMatrix;
    [auto][a] property float lightIntensity0;
    
    #if FLORA_NORMAL_MAP
        [material][a] property float floraNormalMapScale;
    #endif
    [material][a] property float2 floraRoughnessMetallic;
    [material][a] property float2 floraBottomOcclusionShadow;
    
    #if FLORA_FAKE_SHADOW
        uniform sampler2D floraFakeShadow;
        
        [material][a] property float floraFakeShadowIntensity;
        [material][a] property float4 floraFakeShadowOffsetScale;
        [material][a] property float2 floraFakeShadowAnimationFactor;
    #endif

    [auto][a] property float3 cameraPosition;
#elif FLORA_LOD_TRANSITION
    [auto][a] property float3 cameraPosition;
#endif
#if FLORA_LOD_TRANSITION_NEAR
    [material][a] property float2 floraLodTransitionNearRange;
#endif
#if FLORA_LOD_TRANSITION_FAR
    [material][a] property float2 floraLodTransitionFarRange;
#endif
#if ALPHATEST && ALPHATESTVALUE
    [material][a] property float alphatestThreshold = 0.0;
#endif
#if DEBUG_UNLIT
    [material][a] property float4 debugFlatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    float2 texCoord = float2(input.texCoord);

    #if FLORA_PBR_LIGHTING
        half4 baseColor = half4(tex2D(baseColorMap, texCoord));
    #else
        half4 baseColor = half4(tex2D(albedo, texCoord));
    #endif
    #if (ALPHATEST || FLORA_LOD_TRANSITION) && (DRAW_DEPTH_ONLY || (!VIEW_MODE_OVERDRAW_HEAT && !DEBUG_UNLIT))
        #if ALPHATEST
            half alpha = baseColor.a;
        #else
            half alpha = half(1.0);
        #endif
        #if FLORA_LOD_TRANSITION
            float2 xyNDC = input.projPos.xy / input.projPos.w;
            half distanceToCamera = half(length(input.worldPos.xy - cameraPosition.xy));
            #if FLORA_LOD_TRANSITION_NEAR
                half thresholdNear = smoothstep(half(floraLodTransitionNearRange.x), half(floraLodTransitionNearRange.y), distanceToCamera);
                alpha *= CalculateLodTransitionAlpha(xyNDC, thresholdNear);
            #endif
            #if FLORA_LOD_TRANSITION_FAR
                half thresholdFar = smoothstep(half(floraLodTransitionFarRange.x), half(floraLodTransitionFarRange.y), distanceToCamera) - half(1.0);
                alpha *= CalculateLodTransitionAlpha(xyNDC, thresholdFar);
            #endif
        #endif
        #if ALPHATESTVALUE
            if(alpha < half(alphatestThreshold) discard;
        #else
            if(alpha < half(0.5)) discard;
        #endif
    #endif

    #if DRAW_DEPTH_ONLY
        output.color = half(input.projPos.z) / half(input.projPos.w) * half(ndcToZMappingScale) + half(ndcToZMappingOffset);
    #else
        #if FLORA_PBR_LIGHTING
            baseColor.rgb *= half3(tex2D(floraPbrColorMap, float2(input.uvColor.xy)).rgb);
        #else
            half4 colorMapFetch = half4(tex2D(floraColorMap, float2(input.uvColor.xy)));

            #if GLOBAL_TINT
                half lightmapBrightness = half(floraLightmapAdjustment.r);
                half lightmapContrast = half(floraLightmapAdjustment.g);
                half lightmapGamma = half(floraLightmapAdjustment.b);
                
                colorMapFetch.a = pow(colorMapFetch.a, lightmapGamma);
                colorMapFetch.a = (colorMapFetch.a - 0.5) * lightmapContrast + 0.5;
                colorMapFetch.a += lightmapBrightness;
            #endif

            baseColor.rgb *= colorMapFetch.rgb * colorMapFetch.a;
        #endif

        #if !FLORA_PBR_LIGHTING && GLOBAL_TINT
            baseColor.rgb *= half3(globalFlatColor.rgb) * half(2.0);
        #endif

        #if FLORA_LAYING
            half layingStrength = input.uvColor.z;
            #if FLORA_PBR_LIGHTING;
                half3 layingColorFactor = half3(floraLayingPbrColorFactor);
            #else
                half3 layingColorFactor = half3(floraLayingColorFactor);
            #endif
            baseColor.rgb *= lerp(half3(1.0, 1.0, 1.0), layingColorFactor, layingStrength);
        #endif

        #if FLORA_PBR_LIGHTING
            #if FLORA_NORMAL_MAP
                half3 baseNormal = half3(half2(FP_SWIZZLE(tex2D(baseNormalMap, texCoord))), half(1.0));
                baseNormal.xy = baseNormal.xy * half(2.0) - half(1.0);
                baseNormal.z = sqrt(half(1.0) - saturate(dot(baseNormal.xy, baseNormal.xy)));

                baseNormal.xy *= half(floraNormalMapScale);

                half3 N = normalize(half3(
                    dot(baseNormal, input.tangentToWorld0.xyz), 
                    dot(baseNormal, input.tangentToWorld1.xyz), 
                    dot(baseNormal, input.tangentToWorld2.xyz)));

                half3 polygonN = normalize(half3(
                    input.tangentToWorld0.z, 
                    input.tangentToWorld1.z, 
                    input.tangentToWorld2.z));
            #else
                half3 N = normalize(input.normal.xyz);
                half3 polygonN = N;
            #endif
            
            half3 V = half3(normalize(cameraPosition - input.worldPos.xyz));
            
            half3 L = half3(lightPosition0.xyz);
            L = half3(mul(float4(float3(L.xyz), 0.0), invViewMatrix).xyz);
            
            half2 worldUV = half(0.5) - half2(input.worldPos.xy / worldSize.xy);
            worldUV = half2(half(1.0) - worldUV.x, worldUV.y);

            #if FLORA_EDGE_MAP
                half edgeFactor = half(tex2D(floraEdgeMap, float2(worldUV)).r);
            #else
                half edgeFactor = half(0.0);
            #endif

            #if FLORA_NORMAL_MAP
                half localHeight = input.tangentToWorld0.w;
            #else
                half localHeight = input.normal.w;
            #endif

            half lightingFactor = lerp(localHeight, half(1.0), edgeFactor);

            half occlusion = lerp(half(floraBottomOcclusionShadow.x), half(1.0), lightingFactor);
            half shadow = lerp(half(floraBottomOcclusionShadow.y), half(1.0), lightingFactor);

            half2 lightmapDirAndAO = half2(FP_SWIZZLE(tex2D(floraLightmap, float2(worldUV))));
            
            occlusion *= lightmapDirAndAO.y;

            #if RECEIVE_SHADOW
                half4 shadowInfo = getCascadedShadow(float4(input.worldPos, 1.0), input.shadowPos, half4(input.projPos), half3(0.0, 0.0, 1.0), 1.0);
                shadow *= lerp(lightmapDirAndAO.x, shadowInfo.w, shadowInfo.z);
            #else
                shadow *= lightmapDirAndAO.x;
            #endif

            #if FLORA_FAKE_SHADOW
                half2 fakeShadowTexCoord = input.texCoord * half2(floraFakeShadowOffsetScale.zw) + half2(floraFakeShadowOffsetScale.xy);

                #if FLORA_ANIMATION
                    #if FLORA_NORMAL_MAP
                        half2 animation = half2(input.tangentToWorld1.w, input.tangentToWorld2.w);
                    #else
                        half2 animation = input.animation;
                    #endif
                    fakeShadowTexCoord += animation * half2(floraFakeShadowAnimationFactor) * localHeight;
                #endif

                half fakeShadow = half(tex2D(floraFakeShadow, float2(fakeShadowTexCoord)).r);
                half fakeShadowIntensity = half(floraFakeShadowIntensity) * (half(1.0 - edgeFactor));
                #if FLORA_LAYING
                    fakeShadowIntensity *= half(1.0) - layingStrength;
                #endif

                shadow *= lerp(half(1.0), fakeShadow, fakeShadowIntensity);
            #endif
            
            half roughness = half(floraRoughnessMetallic.x);
            half metallic = half(floraRoughnessMetallic.y);

            #if GLOBAL_PBR_TINT
                baseColor.rgb *= half3(floraBaseColorPbrTint) * half(2.0);
                roughness *= half(floraRoughnessPbrTint) * half(2.0);
            #endif

            // saturate for energy conservation
            baseColor = saturate(baseColor);
            roughness = saturate(roughness);
            occlusion = saturate(occlusion);

            output.color.rgb = getPBR(polygonN, N, V, L, half3(lightColor0), half(lightIntensity0), baseColor.rgb, metallic, roughness, occlusion, shadow, half3(0.0, 0.0, 0.0));
            output.color.rgb = half3(LinearToSRGB(output.color.r), LinearToSRGB(output.color.g), LinearToSRGB(output.color.b));
        #else
            output.color.rgb = baseColor.rgb;
            #if RECEIVE_SHADOW
                half4 shadowInfo = getCascadedShadow(float4(input.worldPos, 1.0), input.shadowPos, half4(input.projPos), half3(0.0, 0.0, 1.0), 1.0);
                half3 shadowColor = getShadowColor(shadowInfo);

                output.color.rgb *= shadowColor;
            #endif
        #endif
        output.color.a = half(1.0);

        #if USE_VERTEX_FOG
            half varFogAmoung = input.varFog.a;
            half3 varFogColor  = input.varFog.rgb;
            output.color.rgb = lerp(output.color.rgb, varFogColor, varFogAmoung);
        #endif

        #if FLORA_PBR_LIGHTING
            #if VIEW_ALBEDO && !VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
                output.color = half4(LinearToSRGB(baseColor.r), LinearToSRGB(baseColor.g), LinearToSRGB(baseColor.b), baseColor.a);
            #endif

            #if VIEW_ALL
                #if VIEW_NORMAL
                    #if FLORA_NORMAL_MAP
                        output.color = half4(baseNormal * half(0.5) + half(0.5), half(1.0));
                    #else
                        output.color = half4(0.5, 0.5, 1.0, 1.0);
                    #endif
                #endif

                #if VIEW_NORMAL_FINAL
                    output.color = half4(N.xyz * half(0.5) + half(0.5), half(1.0));
                #endif

                #if VIEW_ROUGHNESS
                    output.color = half4(roughness, roughness, roughness, half(1.0));
                #endif

                #if VIEW_METALLIC
                    output.color = half4(metallic, metallic, metallic, half(1.0));
                #endif

                #if VIEW_AMBIENTOCCLUSION
                    output.color = half4(occlusion, occlusion, occlusion, half(1.0));
                #endif
            #endif
        #endif
        
        #if RECEIVE_SHADOW && DEBUG_SHADOW_CASCADES
            #if FLORA_PBR_LIGHTING
                half3 shadowColor = getShadowColor(shadowInfo);
            #endif
            output.color.rgb = shadowColor;
        #endif
    #endif

    #include "debug-modify-color-half.slh"
    
    return output;
}
