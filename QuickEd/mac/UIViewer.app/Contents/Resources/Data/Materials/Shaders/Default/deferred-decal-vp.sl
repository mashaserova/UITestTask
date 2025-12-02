#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined DECAL_BACK_SIDE_FADE 0

#define DRAW_FLORA_LAYING (PASS_NAME == PASS_FLORALAYING)

vertex_in
{
    [vertex] float3 position : POSITION;
    [instance] float4 worldMatrix0 : TEXCOORD0;
    [instance] float4 worldMatrix1 : TEXCOORD1;
    [instance] float4 worldMatrix2 : TEXCOORD2;
    [instance] float4 invWorldMatrix0 : TEXCOORD3;
    [instance] float4 invWorldMatrix1 : TEXCOORD4;
    [instance] float4 invWorldMatrix2 : TEXCOORD5;
    [instance] float4 parameters : TEXCOORD6;
    [instance] float4 uvOffsetScale : TEXCOORD7;
};

vertex_out
{
    float4 position : SV_POSITION;
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

[auto][a] property float4x4 viewProjMatrix;
#if DRAW_FLORA_LAYING
    [auto][a] property float3 primaryCameraPosition;
#else
    [auto][a] property float3 cameraPosition;
#endif

#if USE_VERTEX_FOG
    [auto][a] property float4x4 viewMatrix;
#endif

#if USE_VERTEX_FOG && FOG_ATMOSPHERE
    [auto][a] property float4 lightPosition0;
#endif

#if FADE_OUT_WITH_TIME
    [auto][a] property float globalTime;
    [auto][a] property float treadsNearFadeDistance;
    [auto][a] property float treadsFarFadeDistance;
    [auto][a] property float2 fadeOutTimeStartEnd;
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    float4x4 worldMatrix = float4x4(
        float4(input.worldMatrix0.x,  input.worldMatrix1.x,  input.worldMatrix2.x, 0.0),
        float4(input.worldMatrix0.y,  input.worldMatrix1.y,  input.worldMatrix2.y, 0.0),
        float4(input.worldMatrix0.z,  input.worldMatrix1.z,  input.worldMatrix2.z, 0.0),
        float4(input.worldMatrix0.w,  input.worldMatrix1.w,  input.worldMatrix2.w, 1.0)
    );

    #if DECAL_TREAD
        float4 modelPos = float4(input.position.xyz, 1.0);
        modelPos.y = lerp(modelPos.y, (modelPos.y * input.parameters.z + input.parameters.w), modelPos.x + 0.5);
        float4 worldPosition = mul(modelPos, worldMatrix);
        float nearFadeDistance = treadsNearFadeDistance;
        float farFadeDistance = treadsFarFadeDistance;
    #else
        float4 worldPosition = mul(float4(input.position.xyz, 1.0), worldMatrix);
        float nearFadeDistance = input.parameters.y;
        float farFadeDistance = input.parameters.z;
    #endif
    output.position = mul(worldPosition, viewProjMatrix);

    #if DRAW_FLORA_LAYING
        float3 toCamera = primaryCameraPosition - worldMatrix[3].xyz;
    #else
        float3 toCamera = cameraPosition - worldMatrix[3].xyz;
    #endif
    float distanceToCamera = length(toCamera);

    float fadeOutDistTerm = 1.0 - smoothstep(nearFadeDistance, farFadeDistance, distanceToCamera);

    #if FADE_OUT_WITH_TIME
        float fadeOutTime = globalTime - input.parameters.x;
        float fadeOutTimeTerm = (1.0 - smoothstep(fadeOutTimeStartEnd.x, fadeOutTimeStartEnd.y, fadeOutTime));
        float opacity = fadeOutDistTerm * fadeOutTimeTerm;
    #else
        float opacity = fadeOutDistTerm * input.parameters.x;
    #endif

    output.varProjectedPosition = output.position;

    #if DRAW_FLORA_LAYING
        float4 localDir = float4(0.0, -1.0, 0.2, 0.0);
        half3 worldDir = normalize(half3(mul(localDir, worldMatrix).xyz));
        output.worldDirStrength = worldDir * half(opacity) * half(0.5) + half(0.5);
    #else
        output.invWorldMatrix0 = input.invWorldMatrix0;
        output.invWorldMatrix1 = input.invWorldMatrix1;
        output.invWorldMatrix2 = input.invWorldMatrix2;
        
        output.parameters = input.parameters;
        #if DECAL_TREAD
            output.parameters.x = opacity;
        #else
            output.parameters.x *= opacity;
        #endif
        output.uvOffsetScale = input.uvOffsetScale;

        #if DECAL_BACK_SIDE_FADE
            toCamera /= distanceToCamera; // normalize
            const float3 N = normalize(worldMatrix[2].xyz);
            output.parameters.x *= smoothstep(-0.2, 0.1, dot(N, toCamera));
        #endif

        #if USE_VERTEX_FOG
            float3 FOG_view_position = mul(worldPosition, viewMatrix).xyz;
            #define FOG_to_light_dir lightPosition0.xyz
            #define FOG_eye_position cameraPosition
            #define FOG_in_position input.position
            #define FOG_world_position worldPosition
            #include "vp-fog-math.slh"
            output.varFog = half4(FOG_result);
        #endif
    #endif

    return output;
}