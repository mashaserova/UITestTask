#include "common.slh"

#ensuredefined FLORA_LOD_TRANSITION_NEAR 0
#ensuredefined FLORA_LOD_TRANSITION_FAR 0
#ensuredefined FLORA_BILLBOARD 0
#ensuredefined FLORA_AMBIENT_ANIMATION 0
#ensuredefined FLORA_WIND_ANIMATION 0
#ensuredefined FLORA_PBR_LIGHTING 0
#ensuredefined FLORA_NORMAL_MAP 0
#ensuredefined FLORA_FAKE_SHADOW 0
#ensuredefined FLORA_LAYING 0
#ensuredefined FLORA_WAVE_ANIMATION 0

#ensuredefined VEGETATION_BEND 0

#define FLORA_LOD_TRANSITION (FLORA_LOD_TRANSITION_NEAR || FLORA_LOD_TRANSITION_FAR)
#define FLORA_ANIMATION (FLORA_AMBIENT_ANIMATION || FLORA_WIND_ANIMATION)

#if FLORA_WAVE_ANIMATION
    #include "flora-wave-animation.slh"
#endif
#if FLORA_PBR_LIGHTING
    #include "srgb.slh"
#endif

vertex_in
{
    [vertex] float3 position : POSITION;
    [vertex] float2 texCoord : TEXCOORD0;
    #if FLORA_PBR_LIGHTING
        [vertex] float3 normal : NORMAL;
        #if FLORA_NORMAL_MAP
            [vertex] float3 tangent : TANGENT;
            [vertex] float3 binormal : BINORMAL;
        #endif
    #endif

    [instance] float3 pivotScale : TEXCOORD1;
    #if FLORA_WIND_ANIMATION
        [instance] float2 wind : TEXCOORD2;
    #endif
};

vertex_out
{
    float4 position : SV_POSITION;
    [lowp] half2 texCoord : TEXCOORD0;
    #if DRAW_DEPTH_ONLY
        float4 projPos : TEXCOORD2;
        #if FLORA_LOD_TRANSITION
            float3 worldPos : TEXCOORD3;
        #endif 
    #else
        #if FLORA_LAYING
            [lowp] half3 uvColor : COLOR1; // .z - layingStrength
        #else
            [lowp] half2 uvColor : COLOR1;
        #endif
        #if USE_VERTEX_FOG
            [lowp] half4 varFog : TEXCOORD1;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION
            float4 projPos : TEXCOORD2;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION || FLORA_PBR_LIGHTING
            float3 worldPos : TEXCOORD3;
        #endif
        #if RECEIVE_SHADOW
            float3 shadowPos : COLOR5;
        #endif
        #if FLORA_PBR_LIGHTING
            #if FLORA_NORMAL_MAP
                half4 tangentToWorld0 : TANGENTTOWORLD0; // .w - localHeight
                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    half4 tangentToWorld1 : TANGENTTOWORLD1; // .w - animation.x
                    half4 tangentToWorld2 : TANGENTTOWORLD2; // .w - animation.y
                #else
                    half3 tangentToWorld1 : TANGENTTOWORLD1;
                    half3 tangentToWorld2 : TANGENTTOWORLD2;
                #endif
            #else
                half4 normal : NORMAL; // .w - localHeight
                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    half2 animation : TEXCOORD4;
                #endif
            #endif
        #endif
    #endif
};

uniform sampler2D heightmap;

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
    uniform sampler2D floraLandscapeNormalMap;
#endif

#if FLORA_LAYING
    uniform sampler2D dynamicFloraLayingMap;

    [auto][a] property float4x4 floraLayingViewProj;
    [material][a] property float2 floraLayingFadeOutRange;
#endif

#if USE_VERTEX_FOG
    [auto][a] property float4 lightPosition0;
#endif
#if USE_VERTEX_FOG
    #include "vp-fog-props.slh"
#endif

#if VEGETATION_BEND
    [auto][a] property float3 cameraDirection;
    [auto][a] property float2 viewportSize;
    [auto][a] property float4 grassBendParams;
    [material][a] property float grassBendWeight;
#endif

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

[auto][a] property float4x4 worldMatrix;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 invViewMatrix;
[auto][a] property float4x4 viewProjMatrix;

[auto][a] property float globalTime;
[auto][a] property float3 cameraPosition;

[auto][a] property float heightmapTextureSize;

[material][a] property float3 worldSize;

[material][a] property float3 floraMinScale;
[material][a] property float2 floraScaleRange;
[material][a] property float floraScaleFactor;

[material][a] property float floraCameraBasedTilting;
#if FLORA_AMBIENT_ANIMATION
    [material][a] property float floraInstanceMotion;
    [material][a] property float floraVertexMotion;
#endif
#if FLORA_WIND_ANIMATION
    [material][a] property float floraWindMotion;
#else
    [material][a] property float2 floraAvgWindDisplacement;
#endif

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
    [material][a] property float floraLocalHeight;
    [material][a] property float floraNormalLifting;
#endif

#define PRIME_NUMBER 419

// Such implementation of GetNoise is possible
// because pivot.xy has already been randomized

inline half GetNoise1(float2 pivot)
{
    return half(frac(pivot.y * float(PRIME_NUMBER) + pivot.x));
}

inline half GetNoise2(float2 pivot)
{
    return half(frac(pivot.x * float(PRIME_NUMBER) + pivot.y));
}

inline half Cross2D(half2 a, half2 b)
{
    return a.x * b.y - a.y * b.x;
}

inline half2 Rotate(half2 vec, half sinTheta, half cosTheta)
{
    half tempX = vec.x;
    vec.x = tempX * cosTheta - vec.y * sinTheta;
    vec.y = tempX * sinTheta + vec.y * cosTheta;
    return vec;
}

vertex_out vp_main( vertex_in input )
{
    vertex_out  output;

    float2 pivot = input.pivotScale.xy;

    half3 scale = lerp(half3(floraMinScale), half3(1.0, 1.0, 1.0), half(input.pivotScale.z));
    scale *= lerp(half(floraScaleRange.x), half(floraScaleRange.y), GetNoise2(pivot));

    half theta = GetNoise1(pivot) * half(2.0) * _PI;
    half sinTheta = sin(theta);
    half cosTheta = cos(theta);

    #if FLORA_BILLBOARD
        // Billboard geometry must be y-axis aligned plane
        half2 toCameraHorizontal = half2(normalize(cameraPosition.xy - pivot));
        sinTheta = Cross2D(half2(1.0, 0.0), toCameraHorizontal);
        cosTheta = dot(toCameraHorizontal, half2(1.0, 0.0));
    #endif

    half3 localPos = half3(input.position.xyz);
    localPos.xyz *= scale * half(floraScaleFactor);
    localPos.xy = Rotate(localPos.xy, sinTheta, cosTheta);

    float3 worldPos = float3(localPos);
    worldPos.xy += pivot;

    half2 worldUV = half(0.5) - half2(worldPos.xy / worldSize.xy);

    float2 uvHeight = float2(half(1.0) - worldUV + half(0.5) / half(heightmapTextureSize));
    #if HEIGHTMAP_FLOAT_TEXTURE
        float heightSample = tex2Dlod(heightmap, uvHeight, 0.0).r;
    #else
        float4 heightVec = tex2Dlod(heightmap, uvHeight, 0.0);
        float heightSample = dot(heightVec, float4(0.00022888532845, 0.00366216525521, 0.05859464408331, 0.93751430533303));
    #endif
    worldPos.z += heightSample * worldSize.z;

    #if VEGETATION_BEND
        float3 fromCamera = worldPos - cameraPosition;

        float bendMinScale = grassBendParams.x;
        float bendMoveBackSq = grassBendParams.y;
        float bendCameraScaleWidth = grassBendParams.z * viewportSize.y / viewportSize.x;
        float bendConePow = grassBendParams.w;

        float fromCameraDot = dot(fromCamera, fromCamera);
        float fromCameraProjLength = dot(fromCamera, normalize(cameraDirection));
        float fromCameraRayDist = (fromCameraDot - fromCameraProjLength * fromCameraProjLength) * bendCameraScaleWidth / (pow(fromCameraDot, bendConePow) + bendMoveBackSq);

        half bendScale = lerp(half(1.0), half(clamp(fromCameraRayDist, bendMinScale, 1.0)), half(grassBendWeight));

        localPos.z *= bendScale;
        worldPos.z = heightSample * worldSize.z + float(localPos.z);
    #endif

    #if FLORA_LAYING
        float4 layingProjPos = mul(float4(worldPos, 1.0), floraLayingViewProj);
        float2 layingTexCoord = layingProjPos.xy * float2(0.5, -0.5) + 0.5;

        half currentDepth = half(layingProjPos.z) * half(ndcToZMappingScale) + half(ndcToZMappingOffset);

        half4 layingSample = half4(tex2Dlod(dynamicFloraLayingMap, layingTexCoord, 0.0));
        half3 layingDir = layingSample.xyz * half(2.0) - half(1.0);
        half layingDepth = layingSample.w;

        half layingStrength = length(layingDir);
        layingStrength = currentDepth < layingDepth ? layingStrength : half(0.0);

        half distanceToCamera = half(length(worldPos.xy - cameraPosition.xy));
        half layingFadeOut = smoothstep(half(floraLayingFadeOutRange.x), half(floraLayingFadeOutRange.y), distanceToCamera);
        layingStrength *= half(1.0) - layingFadeOut;

        layingDir = layingStrength > half(0.0) ? normalize(layingDir) : layingDir;
        layingDir = lerp(half3(0.0, 0.0, 1.0), layingDir, layingStrength);

        worldPos += float3(layingDir * localPos.z - half3(0.0, 0.0, localPos.z));
    #endif

    half3 toCamera = half3(normalize(cameraPosition - worldPos));
    // multiplied by 100.0 to avoid precision problems near zero
    half2 fromCameraHorizontal = -normalize(toCamera.xy * half(100.0));
    half2 tilting = fromCameraHorizontal * toCamera.z * half(floraCameraBasedTilting);

    half3 displacement = half3(tilting, 0.0);

    #if FLORA_ANIMATION
        half3 animation = half3(0.0, 0.0, 0.0);
        #if FLORA_AMBIENT_ANIMATION
            half2 instanceMotion;
            instanceMotion.x = half(2.0) * half(sin(pivot.x + pivot.y + globalTime)) + half(1.0);
            instanceMotion.y = half(sin(2.0 * (pivot.x + pivot.y + globalTime))) + half(0.5);

            half3 vertexMotion = normalize(localPos) * half3(1.0, 1.0, 0.35);
            vertexMotion *= half(sin(2.65 * (worldPos.x + worldPos.y + worldPos.z + globalTime)));

            animation += vertexMotion * half(floraVertexMotion);
            animation.xy += instanceMotion * half(floraInstanceMotion);
        #endif
        #if FLORA_WIND_ANIMATION
            animation.xy += half2(input.wind) * half(floraWindMotion);
        #endif
        #if FLORA_WAVE_ANIMATION
            animation += CalculateWaveAnimation(half3(worldPos));
        #endif
        displacement += animation;
    #endif
    #if !FLORA_WIND_ANIMATION
        displacement.xy += half2(floraAvgWindDisplacement);
    #endif
    #if FLORA_LAYING
        displacement *= half(1.0) - layingStrength;
    #endif

    worldPos += float3(displacement * localPos.z);

    output.position = mul(float4(worldPos, 1.0), viewProjMatrix);
    output.texCoord = half2(input.texCoord);

    #if DRAW_DEPTH_ONLY
        output.projPos = output.position;
        #if FLORA_LOD_TRANSITION
            output.worldPos = worldPos;
        #endif 
    #else
        output.uvColor.xy = half2(half(1.0) - worldUV.x, worldUV.y);
        #if FLORA_LAYING
            output.uvColor.z = layingStrength;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION
            output.projPos = output.position;
        #endif
        #if RECEIVE_SHADOW || FLORA_LOD_TRANSITION || FLORA_PBR_LIGHTING
            output.worldPos = worldPos;
        #endif
        #if RECEIVE_SHADOW
            float4 shadowViewPos = mul(float4(worldPos, 1.0), shadowViewMatrix);
            output.shadowPos = shadowViewPos.xyz;
        #endif

        #if FLORA_PBR_LIGHTING
            float2 uvNormal = float2(half(1.0) - worldUV);
            half3 landscapeNormal = half3(half2(FP_SWIZZLE(tex2Dlod(floraLandscapeNormalMap, uvNormal, 0.0))), half(1.0));
            landscapeNormal.xy = landscapeNormal.xy * half(2.0) - half(1.0);
            landscapeNormal.z = sqrt(half(1.0) - saturate(dot(landscapeNormal.xy, landscapeNormal.xy)));

            #if FLORA_LAYING
                half landscapeNormalFactor = lerp(half(floraNormalLifting), half(1.0), layingStrength);
            #else
                half landscapeNormalFactor = half(floraNormalLifting);
            #endif

            half3 normal = half3(input.normal);
            normal.xy = Rotate(normal.xy, sinTheta, cosTheta);
            normal = normalize(lerp(normal, landscapeNormal, landscapeNormalFactor));

            half localHeight = max(half(input.position.z) / half(floraLocalHeight), half(0.0));

            #if FLORA_NORMAL_MAP
                half3 tangent = half3(input.tangent);
                tangent.xy = Rotate(tangent.xy, sinTheta, cosTheta);

                half3 tProjN = dot(tangent, normal) * normal;
                tangent = normalize(tangent - tProjN);

                half3 binormal = half3(input.binormal);
                binormal.xy = Rotate(binormal.xy, sinTheta, cosTheta);

                float3 bProjN = dot(float3(binormal), float3(normal)) * float3(normal);
                float3 bProjT = dot(float3(binormal), float3(tangent)) * float3(tangent);
                binormal = half3(normalize(float3(binormal) - bProjN - bProjT));

                output.tangentToWorld0.xyz = half3(tangent.x, binormal.x, normal.x);
                output.tangentToWorld1.xyz = half3(tangent.y, binormal.y, normal.y);
                output.tangentToWorld2.xyz = half3(tangent.z, binormal.z, normal.z);

                output.tangentToWorld0.w = localHeight;

                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    output.tangentToWorld1.w = animation.x;
                    output.tangentToWorld2.w = animation.y;
                #endif
            #else
                output.normal.xyz = normal;
                output.normal.w = localHeight;

                #if FLORA_FAKE_SHADOW && FLORA_ANIMATION
                    output.animation = animation;
                #endif
            #endif
        #endif

        #if USE_VERTEX_FOG
            float3 posViewSpace = mul(float4(worldPos, 1.0), viewMatrix).xyz;
            float3 toLightViewSpace = lightPosition0.xyz - posViewSpace * lightPosition0.w;
            #define FOG_eye_position cameraPosition
            #define FOG_view_position posViewSpace
            #define FOG_in_position input.position
            #define FOG_to_light_dir toLightViewSpace
            #define FOG_world_position worldPos
            #include "vp-fog-math.slh"
            output.varFog = half4(FOG_result);
        #endif
    #endif

    return output;
}
