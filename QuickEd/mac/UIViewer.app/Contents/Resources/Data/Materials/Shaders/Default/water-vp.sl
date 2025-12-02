#include "common.slh"

#ensuredefined WATER_RENDER_OBJECT 0
#ensuredefined WATER_TESSELLATION 0
#ensuredefined WATER_DEFORMATION 0

vertex_in
{
    [vertex] float3 position : POSITION;
    #if WATER_RENDER_OBJECT
        #if WATER_TESSELLATION
            [instance] float2 offset : TEXCOORD0;
        #elif !PIXEL_LIT
            [vertex] float2 texCoord1 : TEXCOORD1; // decal
        #endif
    #else
        [vertex] float3 normal : NORMAL;
        [vertex] float3 tangent : TANGENT;
        [vertex] float2 texCoord0 : TEXCOORD0;
        #if !PIXEL_LIT
            [vertex] float2 texCoord1 : TEXCOORD1; // decal
        #endif
    #endif
};

vertex_out
{
    float4 position : SV_POSITION;
    #if DRAW_DEPTH_ONLY
        float2 projPosZW : TEXCOORD0;
    #else
        float2 texCoord0 : TEXCOORD0;
        float2 texCoord1 : TEXCOORD1;
        #if PIXEL_LIT
            float3 cameraToPointInTangentSpace : TEXCOORD2;
            #if REAL_REFLECTION
                float3 eyeCoordsPosition : TEXCOORD3;
                float4 normalizedFragPos : TEXCOORD4;
                #if SPECULAR
                    [lowp] half3 varLightVec : TEXCOORD5;
                #endif
            #else
                [lowp] half3 tbnToWorld0 : TEXCOORD3;
                [lowp] half3 tbnToWorld1 : TEXCOORD4;
                [lowp] half3 tbnToWorld2 : TEXCOORD5;
            #endif
            #if WATER_RIPPLES
                float2 ripplesUv : TEXCOORD6;
                float2 ripplesNoiseUv : TEXCOORD7;
            #endif
        #else
            float2 varTexCoordDecal : TEXCOORD2;
            float3 reflectionDirectionInWorldSpace : TEXCOORD3;
        #endif
        #if USE_VERTEX_FOG
            [lowp] half4 varFog : TEXCOORD8;
        #endif
        #if RECEIVE_SHADOW
            float4 worldPos : COLOR1;
            float3 shadowPos : COLOR5;
        #endif
        #if RECEIVE_SHADOW || (PIXEL_LIT && REAL_REFLECTION && RETRIEVE_FRAG_DEPTH_AVAILABLE)
            float4 varProjectedPosition : COLOR2;
        #endif
        #if WATER_DEFORMATION
            [lowp] half foamFactor : COLOR3;
        #endif
    #endif
};

[auto][a] property float4x4 worldMatrix;
[auto][a] property float4x4 viewProjMatrix;
[auto][a] property float4x4 viewMatrix;

#if WATER_DEFORMATION
    uniform sampler2D dynamicWaterDeformationMap;

    [auto][a] property float3 cameraPosition;
    [auto][a] property float3 cameraDirection;

    [auto][a] property float4x4 waterDeformationViewProj;
    [auto][a] property float4 waterDeformationParams; // xy - fadeOutRange, z - maxDeformation, w - cameraBias
#endif

#if !DRAW_DEPTH_ONLY
    [auto][a] property float globalTime;

    #if !WATER_DEFORMATION
        [auto][a] property float3 cameraPosition;
    #endif

    #if USE_VERTEX_FOG
        #if FOG_ATMOSPHERE
            #if !PIXEL_LIT
                [auto][a] property float4x4 worldViewInvTransposeMatrix;
            #endif
            #if !PIXEL_LIT || !(REAL_REFLECTION && SPECULAR)
                [auto][a] property float4 lightPosition0;
            #endif
        #endif
    #endif

    #if PIXEL_LIT
        [auto][a] property float4x4 worldViewInvTransposeMatrix;
        [auto][a] property float4x4 worldInvTransposeMatrix;
        #if REAL_REFLECTION && SPECULAR
            [auto][a] property float4 lightPosition0;
        #endif
        #if REAL_REFLECTION
            [auto][a] property float projectionFlip;
        #endif
    #else
        [auto][a] property float4x4 worldInvTransposeMatrix;
    #endif

    #if WATER_RENDER_OBJECT
        [material][a] property float3 inputTangent;
        [material][a] property float4 texCoordTransform0;
    #endif

    [material][a] property float2 normal0ShiftPerSecond = float2(0, 0);
    [material][a] property float2 normal1ShiftPerSecond = float2(0, 0);
    [material][a] property float normal0Scale = 0;
    [material][a] property float normal1Scale = 0;

    [auto][instance] property float4x4 viewMatrix;

    #if RECEIVE_SHADOW
        [auto][a] property float4x4 shadowViewMatrix;
    #endif

    [material][instance] property float2 normal0ShiftPerSecond = float2(0.0, 0.0);
    [material][instance] property float2 normal1ShiftPerSecond = float2(0.0, 0.0);
    [material][instance] property float normal0Scale = 1.0;
    [material][instance] property float normal1Scale = 1.0;

#if PIXEL_LIT && WATER_RIPPLES
    [material][instance] property float ripplesUvScale = 1.0;
    [material][instance] property float ripplesNoiseUvScale = 1.0;
    [material][instance] property float2 ripplesNoiseUvShiftPerSecond = float2(0.0, 0.0);
#endif

    #include "vp-fog-props.slh"
    #include "materials-vertex-properties.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    float3 localPosition = input.position.xyz;
    #if WATER_RENDER_OBJECT && WATER_TESSELLATION
        localPosition.xy += input.offset.xy;
    #endif
    float4 worldPosition = mul(float4(localPosition, 1.0), worldMatrix);

    #if WATER_DEFORMATION
        half2 deformationFadeOutRange = half2(waterDeformationParams.xy);
        half3 deformationCenter = half3(cameraPosition) + (half3(cameraDirection) * half(waterDeformationParams.w));

        half deformationDistance = half(length(worldPosition.xy - float2(deformationCenter.xy)));
        half deformationFactor = half(1.0) - smoothstep(deformationFadeOutRange.x, deformationFadeOutRange.y, deformationDistance);

        float4 deformationProjPos = mul(worldPosition, waterDeformationViewProj);
        float2 deformationTexCoord = deformationProjPos.xy * float2(0.5, -0.5) + 0.5;

        half offset = 0.05;
        half uvOffset = offset / (half(waterDeformationParams.y) * half(2.0)); // waterDeformationParams.y - half of camera width

        half3 deformationSampleWithOffsetX = half3(tex2Dlod(dynamicWaterDeformationMap, deformationTexCoord + float2(uvOffset, 0.0), 0.0).rgb);
        half3 deformationSampleWithOffsetY = half3(tex2Dlod(dynamicWaterDeformationMap, deformationTexCoord + float2(0.0, -uvOffset), 0.0).rgb);
        half3 deformationSample = half3(tex2Dlod(dynamicWaterDeformationMap, deformationTexCoord, 0.0).rgb);

        half3 deformation;
        deformation.x = deformationSampleWithOffsetX.r - deformationSampleWithOffsetX.b;
        deformation.y = deformationSampleWithOffsetY.r - deformationSampleWithOffsetY.b;
        deformation.z = deformationSample.r - deformationSample.b;

        deformation *= deformationFactor;

        worldPosition.z += float(deformation.z * half(waterDeformationParams.z));

        #if !DRAW_DEPTH_ONLY
            output.foamFactor = deformationSample.g * deformationFactor;
            half3 deformationNormal = normalize(half3(deformation.z - deformation.xy, half(offset)));
        #endif
    #endif

    float3 eyeCoordsPosition = mul(worldPosition, viewMatrix).xyz;

    output.position = mul(worldPosition, viewProjMatrix);

    #if DRAW_DEPTH_ONLY
        output.projPosZW.xy = output.position.zw;
    #else
        #if WATER_RENDER_OBJECT
            #if WATER_DEFORMATION
                half3 inNormal = deformationNormal;
                half3 inTangent = half3(inputTangent);

                half3 tProjN = dot(inTangent, inNormal) * inNormal;
                inTangent = normalize(inTangent - tProjN);
            #else
                half3 inNormal = half3(0.0, 0.0, 1.0);
                half3 inTangent = half3(inputTangent);
            #endif

            float2 inTexCoord0 = float2(dot(localPosition.xy, texCoordTransform0.xz),
                                        dot(localPosition.xy, texCoordTransform0.yw));
        #else
            half3 inNormal = half3(input.normal);
            half3 inTangent = half3(input.tangent);
            float2 inTexCoord0 = input.texCoord0;
        #endif

        // texcoords
        output.texCoord0 = inTexCoord0 * normal0Scale + frac(normal0ShiftPerSecond * globalTime);
        output.texCoord1 = float2(inTexCoord0.x + inTexCoord0.y, inTexCoord0.y - inTexCoord0.x) * normal1Scale + frac(normal1ShiftPerSecond * globalTime);

        #if PIXEL_LIT && WATER_RIPPLES
            output.ripplesUv = inTexCoord0 * ripplesUvScale;
            output.ripplesNoiseUv = inTexCoord0 * ripplesNoiseUvScale + frac(ripplesNoiseUvShiftPerSecond * globalTime);
        #endif

        #if PIXEL_LIT
            half3 n = normalize(half3(mul(float4(float3(inNormal), 0.0), worldViewInvTransposeMatrix).xyz));
            half3 t = normalize(half3(mul(float4(float3(inTangent), 0.0), worldViewInvTransposeMatrix).xyz));
            half3 b = cross(n, t);

            output.cameraToPointInTangentSpace.x = dot(eyeCoordsPosition, float3(t));
            output.cameraToPointInTangentSpace.y = dot(eyeCoordsPosition, float3(b));
            output.cameraToPointInTangentSpace.z = dot(eyeCoordsPosition, float3(n));

            #if REAL_REFLECTION
                output.eyeCoordsPosition = eyeCoordsPosition;
                output.normalizedFragPos = output.position;
                output.normalizedFragPos.y *= projectionFlip;
                #if SPECULAR
                    half3 toLightDir = half3(normalize(lightPosition0.xyz - eyeCoordsPosition * lightPosition0.w));
                    output.varLightVec.x = dot(toLightDir, t);
                    output.varLightVec.y = dot(toLightDir, b);
                    output.varLightVec.z = dot(toLightDir, n);
                #endif

                #if RETRIEVE_FRAG_DEPTH_AVAILABLE
                    output.varProjectedPosition = output.position;
                #endif
            #else
                n = normalize(half3(mul(float4(float3(inNormal), 0.0), worldInvTransposeMatrix).xyz));
                t = normalize(half3(mul(float4(float3(inTangent), 0.0), worldInvTransposeMatrix).xyz));
                b = cross(n, t);

                output.tbnToWorld0 = half3(t.x, b.x, n.x);
                output.tbnToWorld1 = half3(t.y, b.y, n.y);
                output.tbnToWorld2 = half3(t.z, b.z, n.z);
            #endif
        #else
            #if !WATER_TESSELLATION
                output.varTexCoordDecal = input.texCoord1;
            #else
                output.varTexCoordDecal = float2(0.0, 0.0);
            #endif
            float3 viewDirectionInWorldSpace = worldPosition.xyz - cameraPosition;
            half3 normalDirectionInWorldSpace = normalize(half3(mul(float4(float3(inNormal), 0.0), worldInvTransposeMatrix).xyz));
            output.reflectionDirectionInWorldSpace = reflect(viewDirectionInWorldSpace, float3(normalDirectionInWorldSpace));
        #endif

        #if USE_VERTEX_FOG
            #define FOG_to_light_dir lightPosition0.xyz
            #define FOG_view_position eyeCoordsPosition
            #define FOG_world_position worldPosition
            #define FOG_eye_position cameraPosition
            #define FOG_in_position input.position
            #include "vp-fog-math.slh" // in{ float3 FOG_view_position, float3 FOG_eye_position, float3 FOG_to_light_dir, float3 FOG_world_position }; out{ float4 FOG_result };
            output.varFog = half4(FOG_result);
        #endif

        #if RECEIVE_SHADOW
            output.worldPos = worldPosition;
            float4 shadowViewPos = mul(worldPosition, shadowViewMatrix);
            output.shadowPos = shadowViewPos.xyz;
            output.varProjectedPosition = output.position;
        #endif
    #endif

    return output;
}
