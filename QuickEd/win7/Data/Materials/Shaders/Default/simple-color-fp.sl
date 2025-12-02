#include "common.slh"
#include "blending.slh"

#ensuredefined SIMPLE_COLOR_RECEIVED_SHADOW_ONLY 0

#define SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED (SIMPLE_COLOR_RECEIVED_SHADOW_ONLY && USE_SHADOW_MAP)
#if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY_ENABLED
    #include "shadow-mapping.slh"
#endif

fragment_in
{
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

fragment_out
{
    float4 color : SV_TARGET0;
};
#if DEBUG_UNLIT
    [material][a] property float4 debugFlatColor = float4(1.0, 0.0, 1.0, 1.0);
#endif
#if FLATCOLOR
    [material][a] property float4 flatColor = float4(1.0, 1.0, 1.0, 1.0);
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;
    #if DEBUG_UNLIT
        output.color = float4(1.0f, 1.0f, 1.0f, 1.0f); // will be set in debug-modify-color.slh
    #else
        output.color = input.varColor;
    #endif

    #if USE_VERTEX_FOG
        float varFogAmoung = float(input.varFog.a);
        float3 varFogColor  = float3(input.varFog.rgb);
        output.color.rgb = lerp(output.color.rgb, varFogColor, varFogAmoung);
    #endif

    #if SIMPLE_COLOR_RECEIVED_SHADOW_ONLY
        #if USE_SHADOW_MAP
            half4 shadowMapInfo;
            shadowMapInfo = getCascadedShadow(input.worldPos, input.shadowPos, half4(input.projectedPosition), half3(input.worldSpaceNormal), half(input.NdotL));
            #if DEBUG_SHADOW_CASCADES
                half3 shadowColor;
                shadowColor = getShadowColor(shadowMapInfo);
                output.color.rgb = float3(shadowColor);
            #else
                output.color.rgb = shadowMapShadowColor.rgb;
                output.color.a = 1.0f - float(shadowMapInfo.x);
                #if FLATCOLOR
                    output.color *= flatColor;
                #endif
            #endif
        #else
            output.color.a = 0.0;
        #endif
    #endif

    #include "debug-modify-color.slh"
    return output;
}
