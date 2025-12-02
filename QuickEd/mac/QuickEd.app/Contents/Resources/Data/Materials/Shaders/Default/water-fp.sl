#include "common.slh"

#ensuredefined WATER_DEFORMATION 0

#if RECEIVE_SHADOW
    #include "shadow-mapping.slh"
#endif
#if SPECULAR
    #include "lighting.slh"
#endif

#if PIXEL_LIT
    #include "fresnel-shlick.slh"
#endif

#if RETRIEVE_FRAG_DEPTH_AVAILABLE && PIXEL_LIT && REAL_REFLECTION
    #include "depth-fetch.slh"
#endif

#if PIXEL_LIT && WATER_RIPPLES
    #include "normal-blending.slh"
#endif

#if FRESNEL_TO_ALPHA
blending 
{ 
    src = src_alpha 
    dst = inv_src_alpha 
}
#endif

fragment_in
{
#if DRAW_DEPTH_ONLY
    float2 projPosZW : TEXCOORD0;
#else
    float2 texCoord0 : TEXCOORD0;
    float2 texCoord1 : TEXCOORD1;
    #if PIXEL_LIT
        float3 cameraToPointInTangentSpace : TEXCOORD2;
        #if REAL_REFLECTION
            float3 eyeCoordsPosition : TEXCOORD3;
            float4 normalizedFragPos : TEXCOORD4;
            #if SPECULAR
                [lowp] half3 varLightVec : TEXCOORD5;
            #endif
        #else
            [lowp] half3 tbnToWorld0 : TEXCOORD3;
            [lowp] half3 tbnToWorld1 : TEXCOORD4;
            [lowp] half3 tbnToWorld2 : TEXCOORD5;
        #endif
        #if WATER_RIPPLES
            float2 ripplesUv : TEXCOORD6;
            float2 ripplesNoiseUv : TEXCOORD7;
        #endif
    #endif
    #if !PIXEL_LIT
        float2 varTexCoordDecal : TEXCOORD2;
        float3 reflectionDirectionInWorldSpace : TEXCOORD3;
    #endif
    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD8;
    #endif
    #if RECEIVE_SHADOW
        float4 worldPos : COLOR1;
        float3 shadowPos : COLOR5;
    #endif
    #if RECEIVE_SHADOW || (PIXEL_LIT && REAL_REFLECTION && RETRIEVE_FRAG_DEPTH_AVAILABLE)
        float4 varProjectedPosition : COLOR2;
    #endif
    #if WATER_DEFORMATION
        [lowp] half foamFactor : COLOR3;
    #endif
#endif
};

fragment_out
{
    half4 color : SV_TARGET0;
};

#if !DRAW_DEPTH_ONLY
    #if PIXEL_LIT
        uniform sampler2D normalmap;
        #if WATER_RIPPLES
            uniform sampler2D ripplesNormalMap;
            uniform sampler2D perlinNoise;
            [auto][a] property float globalTime;
            [material][instance] property float ripplesIntensity = 0.5;
            [material][instance] property float ripplesNormalStrength = 1.0;
            [material][instance] property float ripplesAnimationFrameTime = 0.1;
        #endif
        #if REAL_REFLECTION
            uniform sampler2D dynamicReflection;
            #if REAL_REFRACTION
                uniform sampler2D dynamicRefraction;
            #endif
        #endif
    #else
        uniform sampler2D albedo;
        uniform sampler2D decal;
    #endif

    #if !REAL_REFLECTION
        uniform samplerCUBE cubemap;
    #endif

    #if PIXEL_LIT
        #if REAL_REFLECTION
            [material][a] property float distortionFallSquareDist = 1.0;
            [material][a] property float reflectionDistortion = 0;
            #if REAL_REFRACTION
                [material][a] property float refractionDistortion = 0;
                [material][a] property float3 refractionTintColor = float3(1, 1, 1);
            #endif
            #if SPECULAR
                [material][a] property float inGlossiness = 0.5;
                [material][a] property float inSpecularity = 0.5;
                [auto][a] property float3 lightColor0;
            #endif
        #endif
        #if RECEIVE_SHADOW
            [material][a] property float3 pixelLitShadowColor = float3(0.9, 0.9, 0.9);
        #endif

        [material][a] property float3 reflectionTintColor = float3(1, 1, 1);
        [material][a] property float fresnelBias = 0.0;
        [material][a] property float fresnelPow = 0.0;
    #endif

    #if !PIXEL_LIT
        [material][a] property float3 decalTintColor = float3(0,0,0);
        [material][a] property float3 reflectanceColor = float3(0,0,0);
    #endif

    #if WATER_DEFORMATION
        [material][a] property float4 foamColor = float4(1.0, 1.0, 1.0, 1.0);
    #endif
#endif
#if DEBUG_UNLIT
    [material][a] property float4 debugFlatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    #if DRAW_DEPTH_ONLY
        output.color = half(input.projPosZW.x) / half(input.projPosZW.y) * half(ndcToZMappingScale) + half(ndcToZMappingOffset);
    #else
        float2 varTexCoord0 = input.texCoord0;
        float2 varTexCoord1 = input.texCoord1;
        half4 outColor;

        #if PIXEL_LIT
            #if REAL_REFLECTION && RETRIEVE_FRAG_DEPTH_AVAILABLE
                float4 projectedPosition = input.varProjectedPosition / input.varProjectedPosition.w;
                float depthSample = FetchDepth(projectedPosition);
                float4 sampledPosition = mul(float4(projectedPosition.xy, depthSample, 1.0), invProjMatrix);
                float4 currentPosition = mul(projectedPosition, invProjMatrix);
            #endif

            //compute normal
            half3 normal0 = half3(tex2D(normalmap, varTexCoord0).rgb);
            half3 normal1 = half3(tex2D(normalmap, varTexCoord1).rgb);
            half3 normal = normalize(normal0 + normal1 - half(1.0)); //same as * 2 -2

            #if WATER_RIPPLES
                float2 ripplesUv = input.ripplesUv;
                ripplesUv.x += floor(globalTime / ripplesAnimationFrameTime) * 0.25;
                ripplesUv.y += floor(ripplesUv.x) * 0.25;

                half3 ripplesNormal = half3(tex2D(ripplesNormalMap, ripplesUv).rgb) * half(2.0) - half(1.0);
                ripplesNormal.xy *= half(ripplesNormalStrength);
                ripplesNormal = normalize(ripplesNormal);

                half ripplesNoiseSample = half(FP_A8(tex2D(perlinNoise, input.ripplesNoiseUv)));
                half ripplesFactor = smoothstep(half(ripplesIntensity) - half(0.1), half(ripplesIntensity) + half(0.1), ripplesNoiseSample);

                ripplesNormal = lerp(ripplesNormal, half3(0.0, 0.0, 1.0), ripplesFactor);

                normal = NormalBlendUDN(ripplesNormal, normal);
            #endif

            //compute fresnel
            half3 cameraToPointInTangentSpaceNorm = half3(normalize(input.cameraToPointInTangentSpace));
            half lambertFactor = max(dot(-cameraToPointInTangentSpaceNorm, normal), half(0.0));

            // Workaround for shitty parser
            float fresnelFloat = FresnelShlickCustom(float(lambertFactor), fresnelBias, fresnelPow);
            half fresnel = half(fresnelFloat);

            #if WATER_DEFORMATION
                fresnel = lerp(fresnel, half(1.0), input.foamFactor * half(foamColor.a));
            #endif

            #if REAL_REFLECTION
                float3 eyePos = input.eyeCoordsPosition;
                float2 waveOffset = float2(normal.xy) * max(0.1, 1.0 - dot(eyePos, eyePos) * distortionFallSquareDist);

                #if RETRIEVE_FRAG_DEPTH_AVAILABLE
                    float currentDepth = currentPosition.z / max(currentPosition.w, 0.0001);
                    float sampledDepth =  sampledPosition.z / max(sampledPosition.w, 0.0001);
                    half distanceDifference = half(currentDepth - sampledDepth);
                    half adjustedDifference = abs(distanceDifference * half(2.0)) / half(projectedPosition.z / max(projectedPosition.w, 0.0001));
                    half coastLine = saturate(adjustedDifference);
                    coastLine *= half(1.5) - half(2.5) * half(length(waveOffset));
                    coastLine = saturate(coastLine);

                    fresnel *= coastLine;
                    waveOffset *= float(coastLine);
                #endif

                float4 fragPos = input.normalizedFragPos;
                float2 texturePos =  fragPos.xy / fragPos.w * 0.5 + 0.5;

                half3 reflectionColor = half3(tex2D(dynamicReflection, texturePos + waveOffset * reflectionDistortion).rgb);

                #if REAL_REFRACTION
                    texturePos.y = 1.0 - texturePos.y;

                    half3 refractionColor = half3(tex2D(dynamicRefraction, texturePos + waveOffset * refractionDistortion).rgb);
                    #if RETRIEVE_FRAG_DEPTH_AVAILABLE
                        refractionColor *= lerp(half3(1.0, 1.0, 1.0), half3(refractionTintColor), coastLine);
                    #else
                        refractionColor *= half3(refractionTintColor);
                    #endif

                    half3 resColor = lerp(refractionColor, reflectionColor * half3(reflectionTintColor), fresnel);
                #else
                    half3 resColor = reflectionColor * half3(reflectionTintColor);
                #endif

                #if SPECULAR
                    half3 halfVec = normalize(input.varLightVec - cameraToPointInTangentSpaceNorm);

                    // Workaround for shitty parser
                    float specularTermFloat = BlinnPhong(float(max(dot(halfVec, normal), half(0.0))), inGlossiness, inSpecularity);
                    half specularTerm = half(specularTermFloat);

                    half3 resSpecularColor = half3(lightColor0) * specularTerm * fresnel;
                    resColor += resSpecularColor * reflectionColor;
                #endif

                #if WATER_DEFORMATION
                    resColor = lerp(resColor, half3(foamColor.rgb), input.foamFactor * half(foamColor.a));
                #endif

                #if REAL_REFRACTION
                    outColor = half4(resColor, 1.0);
                #else
                    outColor = half4(resColor, fresnel);
                #endif
            #else
                half3 reflectionVectorInTangentSpace = reflect(cameraToPointInTangentSpaceNorm, normal);
                reflectionVectorInTangentSpace.z = abs(reflectionVectorInTangentSpace.z); //prevent reflection through surface
                half3 reflectionVectorInWorldSpace = half3(
                    dot(reflectionVectorInTangentSpace, input.tbnToWorld0),
                    dot(reflectionVectorInTangentSpace, input.tbnToWorld1),
                    dot(reflectionVectorInTangentSpace, input.tbnToWorld2)
                );
                half3 reflectionColor = half3(texCUBE(cubemap, float3(reflectionVectorInWorldSpace)).rgb) * half3(reflectionTintColor);

                #if WATER_DEFORMATION
                    reflectionColor = lerp(reflectionColor, half3(foamColor.rgb), input.foamFactor * half(foamColor.a));
                #endif

                outColor = half4(reflectionColor, fresnel);
            #endif
        #else
            half3 reflectionColor = half3(texCUBE(cubemap, input.reflectionDirectionInWorldSpace).rgb);
            half3 textureColorDecal = half3(tex2D(decal, input.varTexCoordDecal).rgb);
            half3 textureColor0 = half3(tex2D(albedo, varTexCoord0).rgb);
            half3 textureColor1 = half3(tex2D(albedo, varTexCoord1).rgb);

            half3 resColor = (textureColor0 * textureColor1) * half(3.0);
            resColor *= half3(decalTintColor) * textureColorDecal;
            resColor += reflectionColor * half3(reflectanceColor);

            #if WATER_DEFORMATION
                resColor = lerp(resColor, half3(foamColor.rgb), input.foamFactor * half(foamColor.a));
            #endif

            outColor = half4(resColor, 1.0);
        #endif

        #if RECEIVE_SHADOW
            half4 shadowInfo;
            half3 shadowColor;
            shadowInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.varProjectedPosition), half3(0.0, 0.0, 1.0), 1.0);
            #if PIXEL_LIT
                shadowColor = lerp(half3(pixelLitShadowColor), half3(1.0, 1.0, 1.0), shadowInfo.x);
            #else
                shadowColor = getShadowColor(shadowInfo);
            #endif

            outColor.rgb *= shadowColor;
        #endif

        #if USE_VERTEX_FOG
            half varFogAmoung = input.varFog.a;
            half3 varFogColor = input.varFog.rgb;

            #if RETRIEVE_FRAG_DEPTH_AVAILABLE && REAL_REFLECTION && PIXEL_LIT
                varFogAmoung *= coastLine;
            #endif

            outColor.rgb = lerp(outColor.rgb, varFogColor, varFogAmoung);
        #endif

        output.color = outColor;
    #endif

    #include "debug-modify-color-half.slh"

    return output;
}

