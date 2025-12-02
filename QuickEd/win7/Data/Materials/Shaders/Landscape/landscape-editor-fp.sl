#include "common.slh"

fragment_in
{
    float4 texCoord : TEXCOORD0;
};

fragment_out
{
    float4 color : SV_TARGET0;
};

uniform sampler2D tileTexture0;
#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
    uniform sampler2D tileHeightTexture;
    uniform sampler2D tileMaskHeightBlend;
#else
    uniform sampler2D tileMask;
#endif
uniform sampler2D colorTexture;

#if LANDSCAPE_TOOL
    uniform sampler2D toolTexture;
#endif

[material][instance] property float3 tileColor0 = float3(1, 1, 1);
[material][instance] property float3 tileColor1 = float3(1, 1, 1);
[material][instance] property float3 tileColor2 = float3(1, 1, 1);
[material][instance] property float3 tileColor3 = float3(1, 1, 1);
#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
    [material][instance] property float4 heightMapScaleColor;
    [material][instance] property float4 heightMapOffsetColor;
    [material][instance] property float4 heightMapSoftnessColor;
#endif

#if LANDSCAPE_CURSOR
    uniform sampler2D cursorTexture;
    [material][instance] property float4 cursorCoordSize = float4(0, 0, 1, 1);
#endif

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
    inline float3 HeightBlend(float3 input1, float3 input2, float3 input3, float3 input4, float4 height)
    {
        float4 heightStart = max(max(height.x, height.y), max(height.z, height.w)) - heightMapSoftnessColor;
        float4 b = max(height - heightStart,  0.001);
        return ((input1 * b.x) + (input2 * b.y) + (input3 * b.z) + (input4 * b.w)) / (b.x + b.y + b.z + b.w);
    }
#endif

fragment_out fp_main( fragment_in input )
{
    fragment_out output;
    
    float2 texCoord = input.texCoord.xy;
    float2 texCoordTiled = input.texCoord.zw;

    float4 tileColor = tex2D(tileTexture0, texCoordTiled);
    #if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
        float4 mask = tex2D(tileMaskHeightBlend, texCoord);
    #else
        float4 mask = tex2D(tileMask, texCoord);
    #endif
    float4 color = tex2D(colorTexture, texCoord);

    #if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
        float4 hMap = tex2D(tileHeightTexture, texCoordTiled);
        float4 mask2 = saturate(0.15 * (mask * 2.0 - 1.0) + hMap * heightMapScaleColor + heightMapOffsetColor);
        
        float3 color3 = HeightBlend(tileColor.r * tileColor0.rgb, 
                                    tileColor.g * tileColor1.rgb, 
                                    tileColor.b * tileColor2.rgb, 
                                    tileColor.a * tileColor3.rgb, mask2) * color.rgb * 2.0;
    #else
        float3 color3 = (tileColor.r * mask.r * tileColor0.rgb +
                         tileColor.g * mask.g * tileColor1.rgb +
                         tileColor.b * mask.b * tileColor2.rgb +
                         tileColor.a * mask.a * tileColor3.rgb ) * color.rgb * 2.0;
    #endif
    float4 outColor = float4(color3, 1.0);

    #if LANDSCAPE_TOOL
        float4 toolColor = tex2D( toolTexture, texCoord );
        #if LANDSCAPE_TOOL_MIX
            outColor.rgb = (outColor.rgb + toolColor.rgb) / 2.0;
        #else
            outColor.rgb *= 1.0 - toolColor.a;
            outColor.rgb += toolColor.rgb * toolColor.a;
        #endif
    #endif

    #if LANDSCAPE_CURSOR
        float2 cursorCoord = (texCoord - cursorCoordSize.xy) / cursorCoordSize.zw + float2(0.5, 0.5);
        float4 cursorColor = tex2D(cursorTexture, cursorCoord);
        outColor.rgb *= 1.0 - cursorColor.a;
        outColor.rgb += cursorColor.rgb * cursorColor.a;
    #endif

    output.color = outColor;
    
    #include "debug-modify-color.slh"
    return output;
}
