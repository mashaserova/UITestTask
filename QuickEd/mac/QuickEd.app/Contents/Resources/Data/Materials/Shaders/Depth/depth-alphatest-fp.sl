#include "common.slh"
#if LOD_TRANSITION
    #include "lod-transition.slh"
#endif

fragment_in
{
    float4 projectedPosition : TEXCOORD0;

    #if MATERIAL_TEXTURE
        float2 varTexCoord0 : TEXCOORD1;
    #endif

    #if ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD2;
    #endif
    
    #if FLOWMAP
        float3 varFlowData : TEXCOORD3;
    #endif

    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif
};

fragment_out
{
    float4 color : SV_TARGET0;
};

#if MATERIAL_TEXTURE
    #if PBR_TEXTURE_SET
        uniform sampler2D baseColorMap;
    #else
        uniform sampler2D albedo;
    #endif
#endif

#if ALPHA_MASK
    uniform sampler2D alphamask;
#endif

#if FLOWMAP
    uniform sampler2D flowmap;
#endif

#if MATERIAL_TEXTURE && ALPHATEST && ALPHATESTVALUE
    [material][a] property float alphatestThreshold = 0.0;
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
        #if ALPHATEST
            float2 albedoUv = input.varTexCoord0.xy;

            #if PBR_TEXTURE_SET
                textureColor0 = half4(tex2D(baseColorMap, albedoUv));
            #else
                #if FLOWMAP
                    float3 flowData = input.varFlowData;
                    float2 flowDir = float2(tex2D(flowmap, albedoUv).xy) * 2.0 - 1.0;
                    half4 flowSample1 = half4(tex2D(albedo, albedoUv + flowDir * flowData.x));
                    half4 flowSample2 = half4(tex2D(albedo, albedoUv + flowDir * flowData.y));
                    textureColor0 = lerp(flowSample1, flowSample2, half(flowData.z));
                #else
                    textureColor0 = half4(tex2D(albedo, albedoUv));
                #endif
            #endif

            #if ALPHA_MASK
                textureColor0.a *= FP_A8(tex2D(alphamask, input.varTexCoord1));
            #endif

        #else

            #if PBR_TEXTURE_SET
                textureColor0.rgb = half3(tex2D(baseColorMap, input.varTexCoord0).rgb);
            #else
                textureColor0.rgb = half3(tex2D(albedo, input.varTexCoord0).rgb);
            #endif

        #endif
    #endif
    
    #if LOD_TRANSITION
        float2 xyNDC = input.projectedPosition.xy / input.projectedPosition.w;
        textureColor0.a *= CalculateLodTransitionAlpha(xyNDC, half(lodTransitionThreshold));
    #endif

    #if MATERIAL_TEXTURE || LOD_TRANSITION
        #if ALPHATEST
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
    #endif

    output.color = input.projectedPosition.z / input.projectedPosition.w * ndcToZMappingScale + ndcToZMappingOffset;
    
    return output;
}
