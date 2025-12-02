#include "common.slh"
#include "blending.slh"
#if RECEIVE_SHADOW
    #include "shadow-mapping.slh"
#endif
#if LOD_TRANSITION
    #include "lod-transition.slh"
#endif

fragment_in
{    
    [lowp] half4 varVertexColor : COLOR1;

    #if MATERIAL_TEXTURE || TILED_DECAL_MASK
        float2 varTexCoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD1;
    #endif

    #if MATERIAL_DETAIL
        float2 varDetailTexCoord : TEXCOORD2;
    #endif

    #if TILED_DECAL_MASK
        float2 varDecalTileTexCoord : TEXCOORD2;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif

    #if FLOWMAP
        float3 varFlowData : TEXCOORD4;
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        float4 projectedPosition : TEXCOORD7;
    #endif
    
    #if RECEIVE_SHADOW
        float4 worldPos : COLOR2;
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

#if MATERIAL_DECAL
    uniform sampler2D decal;
#endif

#if ALPHA_MASK
    uniform sampler2D alphamask;
#endif

#if MATERIAL_DETAIL
    uniform sampler2D detail;
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

#if LOD_TRANSITION
    [material][a] property float lodTransitionThreshold = 0.0;
#endif

#if !IGNORE_GLOBAL_FLAT_COLOR && GLOBAL_TINT
    [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
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
          #else // end of PIXEL_LIT
            #if FLOWMAP
                float2 flowtc = input.varTexCoord0;
                float3 flowData = input.varFlowData;
                float2 flowDir = float2(tex2D(flowmap, flowtc).xy) * 2.0 - 1.0;
                half3 flowSample1 = half3(tex2D(albedo, input.varTexCoord0 + flowDir*flowData.x).rgb);
                half3 flowSample2 = half3(tex2D(albedo, input.varTexCoord0 + flowDir*flowData.y).rgb);
                textureColor0.rgb = lerp(flowSample1, flowSample2, half(flowData.z));
            #else
                #if TEST_OCCLUSION
                    half4 preColor = half4(tex2D(albedo, input.varTexCoord0));
                    textureColor0.rgb = half3(preColor.rgb*preColor.a);
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
                if(alpha < alphatestThreshold) discard;
            #else
                if(alpha < 0.5) discard;
            #endif
        #endif
        
        #if ALPHASTEPVALUE && ALPHABLEND
            textureColor0.a = half(step(alphaStepValue, float(textureColor0.a)));
        #endif
    #endif

    #if MATERIAL_DECAL
        half3 textureColor1 = half3(tex2D(decal, input.varTexCoord1).rgb);
    #endif

    #if MATERIAL_DETAIL
        half3 detailTextureColor = half3(tex2D(detail, input.varDetailTexCoord).rgb);
    #endif

    // DRAW PHASE

    #if MATERIAL_DECAL
        half3 color = half3(0.0, 0.0, 0.0);

        #if VIEW_ALBEDO
            color = half3(textureColor0.rgb);
        #else
            color = half3(1.0, 1.0, 1.0);
        #endif

        #if VIEW_DIFFUSE
            #if VIEW_ALBEDO
                color *= half3(textureColor1.rgb * 2.0);
            #else
                //do not scale lightmap in view diffuse only case. artist request
                color *= half3(textureColor1.rgb); 
            #endif
        #endif
    #elif MATERIAL_TEXTURE
        half3 color = half3(textureColor0.rgb);
    #else
        half3 color = half3(1.0, 1.0, 1.0);
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

    outColor *= float4(input.varVertexColor);

    #if !IGNORE_GLOBAL_FLAT_COLOR && GLOBAL_TINT
        outColor.rgb *= globalFlatColor.rgb * 2.0;
    #endif

    #if FLATCOLOR
        outColor *= flatColor;
    #endif
    
    #if RECEIVE_SHADOW
        half4 shadowMapInfo;
        shadowMapInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(0.0, 1.0, 0.0), 0.5);
        half3 shadowMapColor;
        shadowMapColor = getShadowColor(shadowMapInfo);
        outColor.rgb *= float3(shadowMapColor);
    #endif

    #if USE_VERTEX_FOG
        float varFogAmoung = float(input.varFog.a);
        float3 varFogColor = float3(input.varFog.rgb);
        outColor.rgb = lerp(outColor.rgb, varFogColor, varFogAmoung);
    #endif
    
    output.color = outColor;

    #include "debug-modify-color.slh"
    return output;
}
