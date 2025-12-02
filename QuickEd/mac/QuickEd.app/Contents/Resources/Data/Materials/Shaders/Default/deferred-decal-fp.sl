#include "common.slh"
#include "blending.slh"

#ensuredefined DECAL_VERTICAL_FADE 0

#define DRAW_FLORA_LAYING (PASS_NAME == PASS_FLORALAYING)

#if RECEIVE_SHADOW && !DRAW_FLORA_LAYING
    #include "shadow-mapping.slh"
#endif
#if !DRAW_FLORA_LAYING
    #include "depth-fetch.slh"
#endif

fragment_in
{
    float4 varProjectedPosition : COLOR0;
    #if DRAW_FLORA_LAYING
        [lowp] half3 worldDirStrength : TEXCOORD0;
    #else

        float4 invWorldMatrix0 : TEXCOORD0;
        float4 invWorldMatrix1 : TEXCOORD1;
        float4 invWorldMatrix2 : TEXCOORD2;
        float4 parameters : TEXCOORD3;
        float4 uvOffsetScale : TEXCOORD4;

        #if USE_VERTEX_FOG
            [lowp] half4 varFog : TEXCOORD5;
        #endif
    #endif
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D albedo;

[auto][a] property float4x4 invViewMatrix;

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if FLATCOLOR
    [material][a] property float4 flatColor = float4(1, 1, 1, 1);
#endif
#if ALPHATEST
    [material][a] property float alphatestThreshold = 0.0;
#endif
#if DECAL_VERTICAL_FADE
    [material][a] property float invDecalVerticalFadeWidth = 0.0;
#endif

#if GLOBAL_TINT
    [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
#endif

fragment_out fp_main(fragment_in input)
{
    fragment_out output;

    #if DRAW_FLORA_LAYING
        float ndcZ = input.varProjectedPosition.z / input.varProjectedPosition.w;
        float depth = ndcZ * ndcToZMappingScale + ndcToZMappingOffset;

        output.color = float4(float3(input.worldDirStrength), depth);
    #else
        float opacity = input.parameters.x;

        float4 projectedPosition = input.varProjectedPosition / input.varProjectedPosition.w;
        float depth = FetchDepth(projectedPosition);
        float4 intermediatePosition = mul(float4(projectedPosition.xy, depth, 1.0), invProjMatrix);
        float3 positionVS = intermediatePosition.xyz / intermediatePosition.w;
        float3 positionWS = mul(float4(positionVS.xyz, 1.0), invViewMatrix).xyz;

        float4x4 inverseWorldMatrix = float4x4(
            float4(input.invWorldMatrix0.x,  input.invWorldMatrix1.x,  input.invWorldMatrix2.x, 0.0),
            float4(input.invWorldMatrix0.y,  input.invWorldMatrix1.y,  input.invWorldMatrix2.y, 0.0),
            float4(input.invWorldMatrix0.z,  input.invWorldMatrix1.z,  input.invWorldMatrix2.z, 0.0),
            float4(input.invWorldMatrix0.w,  input.invWorldMatrix1.w,  input.invWorldMatrix2.w, 1.0)
        );

        float3 positionMS = mul(float4(positionWS, 1.0), inverseWorldMatrix).xyz;

        #if DECAL_TREAD
            float revertedOffsetY = positionMS.y - input.parameters.w * (positionMS.x + 0.5);
            positionMS.y = revertedOffsetY / lerp(1.0, input.parameters.z, (positionMS.x + 0.5)); // zvoni mentam
        #endif

        opacity *= step(abs(positionMS.x), 0.5) * step(abs(positionMS.y), 0.5);
        #if DECAL_VERTICAL_FADE
            opacity *= min((1.0 - abs(positionMS.z * 2.0)) * invDecalVerticalFadeWidth, 1.0);
        #else
            opacity *= step(abs(positionMS.z), 0.5);
        #endif

        float2 decalTexCoord = positionMS.xy + 0.5;
        decalTexCoord = input.uvOffsetScale.xy + input.uvOffsetScale.zw * decalTexCoord;
        #if ALBEDO_TRANSFORM
            // tank treads tiling
            decalTexCoord.y *= input.parameters.y;
        #endif
            float4 albedoSample = tex2D(albedo, decalTexCoord);
            albedoSample.a *= opacity;
        #if DECAL_DEBUG
            albedoSample.xy = decalTexCoord;
            albedoSample.z = 0.0;
            albedoSample.a = input.parameters.x;
        #endif

        output.color = albedoSample;

        #if GLOBAL_TINT
            output.color.rgb *= globalFlatColor.rgb * 2.0;
        #endif

        #if FLATCOLOR
            output.color.rgba *= flatColor.rgba;
        #endif

        #if ALPHATEST && !VIEW_MODE_OVERDRAW_HEAT
            if (output.color.a < alphatestThreshold) discard;
        #endif

        #if RECEIVE_SHADOW
            float4 shadowViewPos = mul(float4(positionWS, 1.0), shadowViewMatrix);
            float3 shadowPos = shadowViewPos.xyz;

            half4 shadowMapInfo = getCascadedShadow(float4(positionWS, 1.0), shadowPos, half4(projectedPosition), half3(0.0, 0.0, 1.0), 1.0);
            half3 shadowColor = getShadowColor(shadowMapInfo);
            output.color.rgb *= float3(shadowColor);
        #endif

        // Fog for decal box. it is ok for small boxes.
        #if USE_VERTEX_FOG
            float varFogAmoung = float(input.varFog.a);
            float3 varFogColor  = float3(input.varFog.rgb);

            output.color.rgb = lerp(output.color.rgb, varFogColor, varFogAmoung);
        #endif

        #if BLENDING == BLENDING_MULTIPLICATIVE
            output.color.rgb = lerp(float3(1.0, 1.0, 1.0), output.color.rgb, output.color.a);
        #endif

        #if VIEW_MODE_OVERDRAW_HEAT
            output.color = float4(0.1f, 0.0f, 0.0f, 0.0f);
            #if ALPHATEST
                output.color.g += 0.1f;
            #endif
        #endif
    #endif

    return output;
}
