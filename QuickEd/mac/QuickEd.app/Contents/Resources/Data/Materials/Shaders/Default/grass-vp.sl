#include "common.slh"
#ensuredefined VEGETATION_SEPARATE_DENSITY_MAP 0
#ensuredefined VEGETATION_DENSITY_CHANNEL 4
#ensuredefined VEGETATION_LIT 0
#ensuredefined FLORA_WAVE_ANIMATION 0
#define USE_VEGETATION_LIT (VEGETATION_LIT && !DRAW_DEPTH_ONLY)

#if FLORA_WAVE_ANIMATION
    #include "flora-wave-animation.slh"
#endif

vertex_in
{
    [vertex] float4 position : POSITION;
    [vertex] float4 texCoordChunkTypeZ : TEXCOORD0;
    [vertex] float3 chunkPivotPos : TEXCOORD1;
    
    #if USE_VEGETATION_LIT
        [vertex] float3 normal : NORMAL;
        [vertex] float3 tangent : TANGENT;
        [vertex] float3 binormal : BINORMAL;
    #endif
    
    [instance] float4 tilePos : TEXCOORD2;
    [instance] float4 windWaveOffsetsX : TEXCOORD3;
    [instance] float4 windWaveOffsetsY : TEXCOORD4;
    [instance] float switchLodIndex : TEXCOORD5;
};

vertex_out
{
    float4 position : SV_POSITION;
    #if DRAW_DEPTH_ONLY || USE_SHADOW_MAP
        float4 projectedPosition : TEXCOORD0;
    #endif

    #if !DRAW_DEPTH_ONLY
        float2 texCoord : TEXCOORD1;
        [lowp] half3 vegetationColor : COLOR0;
        #if USE_VERTEX_FOG
            float4 varFog : TEXCOORD5;
        #endif
        #if USE_SHADOW_MAP
            float4 varWorldPos : COLOR1;

            float3 shadowPos : COLOR5;
        #endif
        
        #if USE_VEGETATION_LIT
            float3 varToLightVec : TEXCOORD2;
            float3 varToCameraVec : TEXCOORD3;
        #endif
    #endif
};

uniform sampler2D heightmap;
uniform sampler2D vegetationColorMap;
#if VEGETATION_SEPARATE_DENSITY_MAP
    uniform sampler2D vegetationDensityMap;
#endif

#if USE_VERTEX_FOG
    [auto][a] property float4x4 worldViewMatrix;
    
    #if FOG_ATMOSPHERE
        #if DISTANCE_ATTENUATION
            [material][a] property float lightIntensity0 = 1.0; 
        #endif
    #endif
    
    #include "vp-fog-props.slh"
#endif

#if USE_VERTEX_FOG || USE_VEGETATION_LIT
    [auto][a] property float4 lightPosition0;
    [auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if USE_VERTEX_FOG || VEGETATION_BEND
    [auto][a] property float3 cameraPosition;
#endif
#if VEGETATION_BEND
    [auto][a] property float3 cameraDirection;
    [material][a] property float grassBendWeight;
    [auto][a] property float4 grassBendParams;
    [auto][a] property float2 viewportSize;
#endif

#if USE_SHADOW_MAP
    [auto][a] property float4x4 shadowViewMatrix;
#endif

[auto][a] property float4x4 worldMatrix;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 viewProjMatrix;

[auto][a] property float heightmapTextureSize;

[material][a] property float3 worldSize;

#if !DRAW_DEPTH_ONLY
    #if GLOBAL_TINT
        [material][a] property float3 globalFlatColor = float3(0.5, 0.5, 0.5);
    #endif
#endif

vertex_out vp_main( vertex_in input )
{
    vertex_out  output;

    float3 chunkPivot = float3(input.chunkPivotPos.x + input.tilePos.x, input.chunkPivotPos.y + input.tilePos.y, input.chunkPivotPos.z);
    
    float2 uv = 0.5 - chunkPivot.xy / worldSize.xy;
    float2 uvColor = float2(1.0 - uv.x, uv.y);
    float2 uvHeight = float2(uvColor.x, 1.0 - uv.y) + 0.5 / heightmapTextureSize;
    
    float4 vegetationColorSample = tex2Dlod(vegetationColorMap, uvColor, 0.0);
    
    #if VEGETATION_SEPARATE_DENSITY_MAP
        float4 vegetationDensity = tex2Dlod(vegetationDensityMap, uvColor, 0.0);
        #if VEGETATION_DENSITY_CHANNEL == 1
            float densityScale = vegetationDensity.r;
        #elif VEGETATION_DENSITY_CHANNEL == 2
            float densityScale = vegetationDensity.g;
        #elif VEGETATION_DENSITY_CHANNEL == 3
            float densityScale = vegetationDensity.b;
        #else
            float densityScale = vegetationDensity.a;
        #endif
    #else
        float densityScale = vegetationColorSample.a;
    #endif
    
    #if HEIGHTMAP_FLOAT_TEXTURE
        float heightSample = tex2Dlod(heightmap, uvHeight, 0.0).r;
    #else
        float4 heightVec = tex2Dlod(heightmap, uvHeight, 0.0);
        float heightSample = dot(heightVec, float4(0.00022888532845, 0.00366216525521, 0.05859464408331, 0.93751430533303));
    #endif

    float height = heightSample * worldSize.z;

    float3 pos = float3(input.position.x + input.tilePos.x, input.position.y + input.tilePos.y, input.position.z);
    pos.z += height;
    chunkPivot.z += height;

    float switchLodScale = step(abs(input.position.w - input.switchLodIndex), 0.1);
    float chunkScale = lerp(input.tilePos.w, 1.0, switchLodScale ) * input.tilePos.z;
    
    int chunkType = int(input.texCoordChunkTypeZ.z);
    pos.x += input.texCoordChunkTypeZ.w * input.windWaveOffsetsX[chunkType];
    pos.y += input.texCoordChunkTypeZ.w * input.windWaveOffsetsY[chunkType];
    
    float grassCameraScale = 1.0;
    #if VEGETATION_BEND        
        float grassMinScale = grassBendParams.x;
        float grassMoveBackSq = grassBendParams.y;
        float grassCameraScaleWidth = grassBendParams.z * viewportSize.y / viewportSize.x;
        float grassConePow = grassBendParams.w;
    
        float3 toCameraW = pos - cameraPosition;
        float toCameraWDot = dot(toCameraW, toCameraW);
        float toCameraWProjLength = dot(toCameraW, normalize(cameraDirection));
        float toCameraRayDist = (toCameraWDot - toCameraWProjLength*toCameraWProjLength) * grassCameraScaleWidth / (pow(toCameraWDot, grassConePow) + grassMoveBackSq);
        grassCameraScale = lerp(1.0, clamp(toCameraRayDist, grassMinScale, 1.0), grassBendWeight);
    #endif
    
    #if FLORA_WAVE_ANIMATION
        half3 waveAnimation = CalculateWaveAnimation(half3(pos));
        pos += float3(waveAnimation) * input.position.z;
    #endif
    
    float finalScale = densityScale * chunkScale * grassCameraScale;
    pos = lerp(chunkPivot, pos, finalScale);
    output.position = mul(float4(pos, 1.0), viewProjMatrix);
    
    output.position.z = lerp(output.position.z, 100000.0, step(finalScale, 0.001)); // clip out
    
    #if DRAW_DEPTH_ONLY || USE_SHADOW_MAP
        output.projectedPosition = output.position;
    #endif
    #if !DRAW_DEPTH_ONLY
        #if USE_VERTEX_FOG || USE_VEGETATION_LIT
            float3 eyeCoordsPosition = mul(float4(pos, 1.0), viewMatrix).xyz;
            float3 toLightDir = lightPosition0.xyz - eyeCoordsPosition * lightPosition0.w;
        #endif
        
        output.texCoord = input.texCoordChunkTypeZ.xy;

        output.vegetationColor = half3(vegetationColorSample.rgb);
        #if GLOBAL_TINT
            output.vegetationColor *= half3(globalFlatColor.rgb) * half(2.0);
        #endif

        #if USE_SHADOW_MAP
            output.varWorldPos = float4(pos, 1.0);

            float4 shadowViewPos = mul(output.varWorldPos, shadowViewMatrix);
            output.shadowPos = shadowViewPos.xyz;
        #endif
        
        #if USE_VERTEX_FOG
            #define FOG_world_position pos
            #define FOG_view_position eyeCoordsPosition
            #define FOG_to_light_dir toLightDir
            #define FOG_eye_position cameraPosition
            #define FOG_in_position input.position
            #include "vp-fog-math.slh"
            output.varFog = FOG_result;
        #endif
        
        #if USE_VEGETATION_LIT
            float3 t = normalize(mul(float4(input.tangent, 0.0), worldViewInvTransposeMatrix).xyz);
            float3 b = normalize(mul(float4(input.binormal, 0.0), worldViewInvTransposeMatrix).xyz);
            float3 n = normalize(mul(float4(input.normal, 0.0), worldViewInvTransposeMatrix).xyz);
    
            float3 toLightTangent;
            toLightTangent.x = dot(toLightDir, t);
            toLightTangent.y = dot(toLightDir, b);
            toLightTangent.z = dot(toLightDir, n);
            
            float3 toCameraDir = -eyeCoordsPosition;
            float3 toCameraTangent;
            toCameraTangent.x = dot(toCameraDir, t);
            toCameraTangent.y = dot(toCameraDir, b);
            toCameraTangent.z = dot(toCameraDir, n);
            
            output.varToLightVec = toLightTangent;
            output.varToCameraVec = toCameraTangent;
        #endif
    #endif

    return output;
}
