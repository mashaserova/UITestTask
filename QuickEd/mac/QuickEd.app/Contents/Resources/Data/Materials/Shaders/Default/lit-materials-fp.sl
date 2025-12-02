#include "common.slh"
#include "blending.slh"
#include "lighting.slh"

#if RECEIVE_SHADOW
    #include "shadow-mapping.slh"
    #if (MAX_POINT_LIGHTS > 0) && POINT_LIGHTS_OVERRIDE_SHADOW
        [auto][a] property float pointLightsOverrideShadowWeight = 1.0;
    #endif
#endif
#if NORMALIZED_BLINN_PHONG
    #include "fresnel-shlick.slh"
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
    #if MATERIAL_TEXTURE || TILED_DECAL_MASK
        float4 varTexCoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD1;
    #endif

    #if MATERIAL_DETAIL
        float2 varDetailTexCoord : TEXCOORD2;
    #endif
    
    #if PIXEL_LIT
        float4 tangentToView0 : NORMAL1;
        float4 tangentToView1 : NORMAL2;
        float4 tangentToView2 : NORMAL3;
        
        #if RECEIVE_SHADOW
            float3 tangentToWorld0 : TANGENTTOWORLD0;
            float3 tangentToWorld1 : TANGENTTOWORLD1;
            float3 tangentToWorld2 : TANGENTTOWORLD2;
        #endif

        [lowp] half4 varToLightVec : COLOR1;
        float3 varToCameraVec : TEXCOORD7;
    #else
        [lowp] half4 varDiffuseColor : COLOR0;

        #if SIMPLE_BLINN_PHONG
            [lowp] half varSpecularColor : TEXCOORD4;
        #elif NORMALIZED_BLINN_PHONG
            [lowp] half4 varSpecularColor : TEXCOORD4;
        #endif
        #if RECEIVE_SHADOW
            float4 worldNormalNdotL : COLOR3;
        #endif
    #endif

    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif

    #if (ENVIRONMENT_MAPPING && (!ENVIRONMENT_MAPPING_NORMALMAP))
        float3 reflectionVector : TEXCOORD6;
    #endif
    
    #if RECEIVE_SHADOW || LOD_TRANSITION
        float4 projectedPosition : POSITION2;
    #endif
    #if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
        float4 worldPos : POSITION3;
    #endif
    #if RECEIVE_SHADOW
        float3 shadowPos : COLOR5;
    #endif

    #if TILED_DECAL_MASK && TILED_DECAL_ANIMATED_EMISSION
        [lowp] half4 aniCamoParams : COLOR2;
    #endif
    #if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
        [lowp] half3 localPos : POSITION1;
    #endif
};

fragment_out
{
    float4 color : SV_TARGET0;
};

#if MATERIAL_TEXTURE
    uniform sampler2D albedo;
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

#if ENVIRONMENT_MAPPING
    uniform samplerCUBE cubemap;
    [material][a] property float3 cubemapIntensity = float3(1.0, 1.0, 1.0);
#endif

#if MATERIAL_TEXTURE && ALPHATEST && ALPHATESTVALUE
    [material][a] property float alphatestThreshold = 0.0;
#endif

#if MATERIAL_TEXTURE && ALPHASTEPVALUE && ALPHABLEND
    [material][a] property float alphaStepValue = 0.5;
#endif

#if PIXEL_LIT
    uniform sampler2D normalmap;

    [material][a] property float inSpecularity = 1.0;
    [material][a] property float3 metalFresnelReflectance = float3(0.5, 0.5, 0.5);
    [material][a] property float normalScale = 1.0;

    [auto][a] property float4 lightPosition0;
    [auto][a] property float4x4 pointLights; // 0,1:(position, radius); 2,3:(color, unused)
#endif

#if TILED_DECAL_MASK
    uniform sampler2D decalmask;
    uniform sampler2D decaltexture;
    [material][a] property float4 decalTileColor = float4(1.0, 1.0, 1.0, 1.0);
    
    #if DECAL_TEXTURE_COUNT > 1
        uniform sampler2D decalTexture1;
        [material][a] property float4 decalTileColor1 = float4(1.0, 1.0, 1.0, 1.0);
    #endif
    #if DECAL_TEXTURE_COUNT > 2
        uniform sampler2D decalTexture2;
        [material][a] property float4 decalTileColor2 = float4(1.0, 1.0, 1.0, 1.0);
    #endif
    #if DECAL_TEXTURE_COUNT > 3
        uniform sampler2D decalTexture3;
        [material][a] property float4 decalTileColor3 = float4(1.0, 1.0, 1.0, 1.0);
    #endif
    #if TILED_DECAL_SPREADING
        #include "decal-spreading.slh"
    #endif
#endif

    [auto][a] property float3 lightAmbientColor0;
    [auto][a] property float3 lightColor0;
    [auto][a] property float4x4 invViewMatrix;

#if NORMALIZED_BLINN_PHONG && VIEW_SPECULAR
    [material][a] property float inGlossiness = 0.5;
#endif

#if FLATCOLOR || FLATALBEDO
    [material][a] property float4 flatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

#if BLEND_WITH_CONST_ALPHA
    [material][a] property float flatAlpha = 1.0;
#endif

#if SETUP_LIGHTMAP && MATERIAL_DECAL
    [material][a] property float lightmapSize = 1.0;
#endif

#if LOD_TRANSITION
    [material][a] property float lodTransitionThreshold = 0.0;
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    // FETCH PHASE
    half4 textureColor0 = half4(1.0, 0.0, 0.0, 1.0);

    #if MATERIAL_TEXTURE
        float2 albedoUv = input.varTexCoord0.xy;

        #if TEST_OCCLUSION
            half4 preColor = half4(tex2D(albedo, input.varTexCoord0.xy));
            textureColor0.rgb = half3(preColor.rgb*preColor.a);
        #else
            textureColor0 = half4(tex2D(albedo, albedoUv));
        #endif

        #if ALPHA_MASK 
            textureColor0.a *= FP_A8(tex2D(alphamask, input.varTexCoord1));
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
                if(alpha < alphatestThreshold) discard;
            #else
                if(alpha < 0.5) discard;
            #endif
        #endif

        #if ALPHASTEPVALUE && ALPHABLEND
            textureColor0.a = half(step(alphaStepValue, float(textureColor0.a)));
        #endif
    #endif

    #if MATERIAL_DETAIL
        half3 detailTextureColor = half3(tex2D(detail, input.varDetailTexCoord).rgb);
    #endif

    #if MATERIAL_DECAL
        half3 textureColor1 = half3(tex2D(decal, input.varTexCoord1).rgb);
        #if SETUP_LIGHTMAP
            textureColor1 = SetupLightmap(input.varTexCoord1, lightmapSize);
        #endif
    #endif

    // DRAW PHASE

    float specularSample = textureColor0.a;

    half3 color = half3(0.0, 0.0, 0.0);
    
#if !PIXEL_LIT
    #if SIMPLE_BLINN_PHONG || NORMALIZED_BLINN_PHONG
        #if VIEW_AMBIENT
            color += half3(lightAmbientColor0);
        #endif

        #if VIEW_DIFFUSE
            color += input.varDiffuseColor.rgb;
        #endif

        #if VIEW_ALBEDO
            #if TILED_DECAL_MASK
                half maskSample = FP_A8(tex2D(decalmask, input.varTexCoord0.xy));
                half4 tileColor = half4(tex2D(decaltexture, input.varTexCoord0.zw).rgba * decalTileColor);
                #if MULTIPLE_DECAL_TEXTURES
                    #include "multiple-decal-textures.slh"
                #endif

                #if TILED_DECAL_ANIM_MASK
                    half fullMask = maskSample;
                #else
                    half fullMask = tileColor.a * maskSample;
                #endif

                #if TILED_DECAL_SPREADING || TILED_DECAL_ANIMATED_EMISSION
                    half3 emission = half3(0.0, 0.0, 0.0);
                #endif

                #if TILED_DECAL_SPREADING
                    half spreading = half(1.0);
                    #if TILED_DECAL_NOISE_SPREADING
                        spreading *= GetNoiseBasedSpreading(half(spreadingProgress), input.varTexCoord0.zw);
                    #endif
                    #if TILED_DECAL_SPATIAL_SPREADING
                        spreading *= GetSpatialBasedSpreading(half(spreadingProgress), input.localPos.xyz);
                    #endif

                    half boundary = half(1.0) - abs(half(0.5) - spreading) * half(2.0);
                    emission += lerp(emission.rgb, half3(spreadingBorderColor), boundary * fullMask);

                    fullMask *= spreading;
                #endif
                
                half3 textureCombined = lerp(textureColor0.rgb, tileColor.rgb, fullMask);

                #if TILED_DECAL_ANIMATED_EMISSION
                    half brightness = dot(tileColor.rgb, half3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)); // (r + g + b) / 3.0
                    half selector = saturate(brightness * input.aniCamoParams.z - input.aniCamoParams.x)
                                  - saturate(brightness * input.aniCamoParams.z - input.aniCamoParams.y);

                    #if TILED_DECAL_ANIM_MASK
                        half animMask = tileColor.a * fullMask;
                    #else
                        half animMask = fullMask;
                    #endif

                    emission += tileColor.rgb * (animMask * input.aniCamoParams.w * selector);
                #endif

                #if TILED_DECAL_SPREADING || TILED_DECAL_ANIMATED_EMISSION
                    color = color * textureCombined + emission;
                #else
                    color *= textureCombined;
                #endif
            #else
                color *= textureColor0.rgb;
            #endif
        #endif
    #endif

    #if VIEW_SPECULAR
        #if SIMPLE_BLINN_PHONG
            color += half3((input.varSpecularColor * specularSample) * lightColor0);
        #elif NORMALIZED_BLINN_PHONG
            float specularTerm;
            specularTerm = BlinnPhong(float(input.varSpecularColor.w), inGlossiness * specularSample, 1.0);
            color += input.varSpecularColor.rgb * half3(specularTerm * lightColor0);
        #endif
    #endif

    #if VIEW_ALBEDO &&!VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
        color = textureColor0.rgb;
    #endif
#endif
    
#if PIXEL_LIT
    // lookup normal from normal map, move from [0, 1] to  [-1, 1] range, normalize
    float3 normal = tex2D(normalmap, input.varTexCoord0.xy).rgb * 2.0 - 1.0;
    #if RECEIVE_SHADOW
        float3 normalShady = normal;
    #endif
    
    normal.xy *= normalScale;
    normal = normalize(normal);

    float3 viewNormal = float3(dot(input.tangentToView0.xyz, normal), dot(input.tangentToView1.xyz, normal), dot(input.tangentToView2.xyz, normal));
    
    float3 toCameraNormalized = float3(normalize(input.varToCameraVec));
    float NdotL = 0.0f;

    float3 toLightNormalized = float3(normalize(input.varToLightVec.xyz));
    float3 H = toCameraNormalized + toLightNormalized;
    H = normalize(H);

    // compute diffuse lighting
    NdotL = max(dot(normal, toLightNormalized), 0.0);
    float NdotH = max(dot(normal, H), 0.0);
    float LdotH = max(dot(toLightNormalized, H), 0.0);
    float NdotV = max(dot(normal, toCameraNormalized), 0.0);

    float3 diffuse = lightColor0 * (NdotL / _PI);
    float3 specular = 0.0;

    #if NORMALIZED_BLINN_PHONG
        #if DIELECTRIC
            float fresnelOut = FresnelShlick(NdotV, dielectricFresnelReflectance);
            fresnelOut = FresnelShlick(NdotV, dielectricFresnelReflectance);
        #else
            float3 fresnelOut = FresnelShlickVec3(NdotV, metalFresnelReflectance);
        #endif

        #if (MAX_POINT_LIGHTS > 0)
            float3 viewPosition = float3(input.tangentToView0.w, input.tangentToView1.w, input.tangentToView2.w);
            #if POINT_LIGHTS_OVERRIDE_SHADOW
                float3 pointLightsDiffuse = 0.0;
                pointLightsDiffuse += ApplyLight(pointLights[0], pointLights[2], viewPosition, viewNormal);
                #if (MAX_POINT_LIGHTS > 1)
                    pointLightsDiffuse += ApplyLight(pointLights[1], pointLights[3], viewPosition, viewNormal);
                #endif
                diffuse += pointLightsDiffuse;
            #else
                diffuse += ApplyLight(pointLights[0], pointLights[2], viewPosition, viewNormal);
                #if (MAX_POINT_LIGHTS > 1)
                    diffuse += ApplyLight(pointLights[1], pointLights[3], viewPosition, viewNormal);
                #endif
            #endif
        #endif

        #if VIEW_SPECULAR
            float specularTerm;
            specularTerm = BlinnPhong(NdotH, inGlossiness * specularSample, NdotL * inSpecularity);
            specular = lightColor0 * specularTerm;

            #if ENVIRONMENT_MAPPING
                #if (ENVIRONMENT_MAPPING_NORMALMAP)
                    float3 reflected = -reflect(toCameraNormalized, normal);
                    float3 viewReflected = float3(
                        dot(reflected, input.tangentToView0.xyz),
                        dot(reflected, input.tangentToView1.xyz),
                        dot(reflected, input.tangentToView2.xyz));
                    float3 samplingDirection = mul(float4(viewReflected, 0.0), invViewMatrix).xyz;
                #else
                    float3 samplingDirection = input.reflectionVector;
                #endif
                specular += texCUBE(cubemap, samplingDirection).xyz * cubemapIntensity * specularSample;
            #endif

            specular *= fresnelOut;
        #endif
    #endif

    #if RECEIVE_SHADOW
        half4 shadowInfo;
        half3 shadowColor;

        normalShady.xy *= shadowLitNormalScale;
        normalShady = normalize(normalShady);

        float NdotLShady = max(dot(normalShady, toLightNormalized), 0.0);

        float3 worldNormal = float3(dot(input.tangentToWorld0.xyz, normalShady), dot(input.tangentToWorld1.xyz, normalShady), dot(input.tangentToWorld2.xyz, normalShady));
        shadowInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(worldNormal), half(NdotLShady));
        #if NORMALIZED_BLINN_PHONG && (MAX_POINT_LIGHTS > 0) && POINT_LIGHTS_OVERRIDE_SHADOW
            shadowInfo.x = lerp(shadowInfo.x, half(1.0), half(min(pointLightsOverrideShadowWeight * abs(pointLightsDiffuse.x + pointLightsDiffuse.y + pointLightsDiffuse.z), 1.0)));
        #endif
        shadowColor = getShadowColor(shadowInfo);

        #if VIEW_DIFFUSE
            diffuse *= shadowLitDiffuseSpecAmbientMult.x + (1.0 - shadowLitDiffuseSpecAmbientMult.x) * float(shadowInfo.x);
        #endif
        #if VIEW_SPECULAR
            specular *= shadowLitDiffuseSpecAmbientMult.y + (1.0 - shadowLitDiffuseSpecAmbientMult.y) * float(shadowInfo.x);
        #endif
    #endif

    #if VIEW_AMBIENT
        #if RECEIVE_SHADOW
            color += half3(lightAmbientColor0) * saturate(shadowColor * half(shadowLitDiffuseSpecAmbientMult.z));
        #else
            color += half3(lightAmbientColor0);
        #endif
    #endif

    #if VIEW_DIFFUSE
        color += half3(diffuse);
    #endif

    #if VIEW_ALBEDO
        #if TILED_DECAL_MASK
            half maskSample = FP_A8(tex2D(decalmask, input.varTexCoord0.xy));
            half4 tileColor = half4(tex2D(decaltexture, input.varTexCoord0.zw).rgba * decalTileColor);
            #if MULTIPLE_DECAL_TEXTURES
                #include "multiple-decal-textures.slh"
            #endif
            #if TILED_DECAL_ANIM_MASK
                half fullMask = maskSample;
            #else
                half fullMask = tileColor.a * maskSample;
            #endif
            
            #if TILED_DECAL_SPREADING || TILED_DECAL_ANIMATED_EMISSION
                half3 emission = half3(0.0, 0.0, 0.0);
            #endif

            #if TILED_DECAL_SPREADING
                half spreading = half(1.0);
                #if TILED_DECAL_NOISE_SPREADING
                    spreading *= GetNoiseBasedSpreading(half(spreadingProgress), input.varTexCoord0.zw);
                #endif
                #if TILED_DECAL_SPATIAL_SPREADING
                    spreading *= GetSpatialBasedSpreading(half(spreadingProgress), input.localPos.xyz);
                #endif

                half boundary = half(1.0) - abs(half(0.5) - spreading) * half(2.0);
                emission += lerp(emission.rgb, half3(spreadingBorderColor), boundary * fullMask);

                fullMask *= spreading;
            #endif

            half3 textureCombined = lerp(textureColor0.rgb, tileColor.rgb, fullMask);

            #if TILED_DECAL_ANIMATED_EMISSION
                half brightness = dot(tileColor.rgb, half3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)); // (r + g + b) / 3.0
                half selector = saturate(brightness * input.aniCamoParams.z - input.aniCamoParams.x)
                              - saturate(brightness * input.aniCamoParams.z - input.aniCamoParams.y);
                #if TILED_DECAL_ANIM_MASK
                    half animMask = tileColor.a * fullMask;
                #else
                    half animMask = fullMask;
                #endif

                emission += tileColor.rgb * (animMask * input.aniCamoParams.w * selector);
            #endif

            #if TILED_DECAL_SPREADING || TILED_DECAL_ANIMATED_EMISSION
                color = color * textureCombined + emission;
            #else
                color *= textureCombined;
            #endif
        #else
            color *= textureColor0.rgb;
        #endif
    #endif

    #if VIEW_SPECULAR
        color += half3(specular);
    #endif

    #if VIEW_ALBEDO && !VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
        color = textureColor0.rgb;
    #endif

    #if VIEW_ALL && (VIEW_NORMAL || VIEW_NORMAL_FINAL)
        color = (normal + 1.0) * 0.5;
    #endif
#endif

    #if MATERIAL_DETAIL
        color *= detailTextureColor.rgb * 2.0;
    #endif

    #if ALPHABLEND && MATERIAL_TEXTURE
        output.color = float4(float3(color.rgb), textureColor0.a);
    #else
        output.color = float4(color.r, color.g, color.b, 1.0);
    #endif

    #if VERTEX_COLOR
        output.color *= float4(input.varVertexColor);
    #endif
        
    #if FLATCOLOR
        output.color *= flatColor;
    #endif

    #if BLEND_WITH_CONST_ALPHA
        output.color.a = flatAlpha;
    #endif

    #if HIGHLIGHT_COLOR || HIGHLIGHT_WAVE_ANIM
        output.color = ApplyHighlightAnimation(output.color, input.worldPos.z);
    #endif

    #if RECEIVE_SHADOW && !PIXEL_LIT
        half4 shadowInfo;
        half3 shadowColor;
        shadowInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(input.worldNormalNdotL.xyz), half(input.worldNormalNdotL.w));
        shadowColor = getShadowColor(shadowInfo);

        output.color.rgb *= float3(shadowColor);
    #endif

    #if USE_VERTEX_FOG
        float varFogAmoung = float(input.varFog.a);
        float3 varFogColor  = float3(input.varFog.rgb);
        output.color.rgb = lerp(output.color.rgb, varFogColor, varFogAmoung);
    #endif

    #include "debug-modify-color.slh"
    return output;
}
