#include "common.slh"
#define DRAW_DEPTH_ONLY 1
#include "materials-vertex-properties.slh"

vertex_in
{
    float3 position : POSITION;
    
    #if USE_VERTEX_DISPLACEMENT
        float3 normal : NORMAL;
        float2 texcoord1 : TEXCOORD1;
        float4 color0 : COLOR0;
    #endif
    
    #if WIND_ANIMATION
        float flexibility : TEXCOORD5;
    #elif VERTEX_VERTICAL_OFFSET
        float offsetWeight : TEXCOORD5;
    #endif
    
    #include "skinning-vertex-input.slh"
};

vertex_out
{
    float4 position : SV_POSITION;
};

#define NEED_CHAIN_TEXCOORD_OFFSETS 0
#if INSTANCED_CHAIN
    #include "instanced-chain.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;
    #include "materials-vertex-processing.slh"
    return output;
}
