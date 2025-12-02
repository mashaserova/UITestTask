#include "blending.slh"
#include "common.slh"

#define COLOR_MUL 0
#define COLOR_ADD 1
#define ALPHA_MUL 2
#define ALPHA_ADD 3

#ifndef COLOR_OP
    #define COLOR_OP COLOR_MUL
#endif

#if COLORBLIND_MODE
    #include "colorblind-mode.slh"
#endif

fragment_in
{
#if TEXTURED
    float2  uv      : TEXCOORD0;
#endif
    [lowp] half4   color   : COLOR0;
};
    
fragment_out
{
    float4  color : SV_TARGET0;
};

#if TEXTURED
    uniform sampler2D tex;

    #if CLAMP
        [material][a] property float2 maxUV;
    #endif
#endif

fragment_out fp_main( fragment_in input )
{
    fragment_out    output;

    half4 in_color = input.color;

#if TEXTURED
    #if CLAMP
        float2 in_uv = clamp(input.uv, 0.0, maxUV);
    #else
        float2 in_uv = input.uv;
    #endif

    #if ALPHA8
        half4 resColor = half4( 1.0, 1.0, 1.0, FP_A8(tex2D( tex, in_uv )) );
    #elif RED8_TO_ALPHA
        half4 resColor = half4( 1.0, 1.0, 1.0, tex2D( tex, in_uv ).r );
    #else
        half4 resColor = half4(tex2D( tex, in_uv ));
    #endif

    #if (COLOR_OP == COLOR_MUL)
        resColor = resColor * in_color;
    #elif (COLOR_OP == COLOR_ADD)
        resColor = resColor + in_color;
    #elif (COLOR_OP == ALPHA_MUL)
        resColor.a = resColor.a * in_color.a;
    #elif (COLOR_OP == ALPHA_ADD)
        resColor.a = resColor.a + in_color.a;
    #endif
#else //TEXTURED

    half4 resColor = in_color;

#endif //TEXTURED

#if GRAYSCALE
    half gray = dot(resColor.rgb, half3(0.3, 0.59, 0.11));
    resColor.rgb = half3(gray,gray,gray);
#endif

#if ALPHATEST && !VIEW_MODE_OVERDRAW_HEAT
    half alpha = resColor.a;
    if( alpha < 0.5 ) discard;
#endif

    output.color = float4(resColor);

    #if COLORBLIND_MODE
        output.color.rgb = ApplyColorblindMode(output.color.rgb);
    #endif
    
    #include "debug-overdraw-2d.slh"
    return output;
}
