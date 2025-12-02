#include "blending.slh"
#include "common.slh"

#if COLORBLIND_MODE
    #include "colorblind-mode.slh"
#endif

fragment_in
{
    float2  uv      : TEXCOORD0;
    [lowp] half4   color   : COLOR0;
};

fragment_out
{
    float4  color   : SV_TARGET0;
};

sampler2D tex;

[material][instance] property float smoothing;

fragment_out fp_main( fragment_in input )
{
    fragment_out    output;

    half4   in_color = input.color;
    float2  in_uv    = input.uv;

    half distance = FP_A8(tex2D( tex, in_uv ));
    half alpha = smoothstep(half(0.5) - half(smoothing), half(0.5) + half(smoothing), distance);
    alpha = min(alpha, in_color.a);

    output.color = float4(half4(in_color.rgb, alpha));

    #if COLORBLIND_MODE
        output.color.rgb = ApplyColorblindMode(output.color.rgb);
    #endif
    
    #include "debug-overdraw-2d.slh"
    return output;
}
