#include "common.slh"

#ensuredefined SPEEDTREE_JOINT_LENGTHWISE_TRANSFORM 0

vertex_in
{
    float3 position : POSITION;

    #if PBR_SPEEDTREE
        float3 normal : NORMAL;
        float3 tangent : TANGENT;
        float3 binormal : BINORMAL;
    #endif

    float2 texcoord0 : TEXCOORD0;
    float4 color0 : COLOR0;

    float4 pivot : TEXCOORD4;

    float flexibility : TEXCOORD5;
    float2 angleSinCos : TEXCOORD6;

    #if SPEEDTREE_JOINT_TRANSFORM
        float jointIndex : BLENDINDICES;
    #endif
};

#if SPEEDTREE_JOINT_TRANSFORM
    #define BUSH_JOINTS_ARRAY_SIZE 32 // should be equal to SpeedTreeObject::BushJointsMaxCount
    [material][cp] property float4 speedtreeJointViewOffsets[BUSH_JOINTS_ARRAY_SIZE] : "bigarray"; // xyz - offset, w - inverse length
#endif

vertex_out
{
    float4 position : SV_POSITION;
    float2 varTexCoord0 : TEXCOORD0;
    [lowp] half4 varVertexColor : COLOR1;

    #if LOD_TRANSITION || (RECEIVE_SHADOW && !DRAW_DEPTH_ONLY)
        float4 projectedPosition : COLOR3;
    #endif

#if !DRAW_DEPTH_ONLY
    #if PBR_SPEEDTREE
        float4 worldPos : COLOR2;
    #endif

    #if RECEIVE_SHADOW
        float4 worldPosShadow : TEXCOORD1;
        float3 shadowPos : COLOR5;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif
    #if PBR_SPEEDTREE
        half3 tangentToWorld0 : TANGENTTOWORLD0;
        half3 tangentToWorld1 : TANGENTTOWORLD1;
        half3 tangentToWorld2 : TANGENTTOWORLD2;
    #endif
#endif
};

////////////////////////////////////////////////////////////////////////////////
// properties

[auto][a] property float3 worldScale;
[auto][a] property float4x4 worldMatrix;
[auto][a] property float4x4 projMatrix;
[auto][a] property float4x4 worldViewMatrix;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 invViewMatrix;
[auto][a] property float4x4 shadowViewMatrix;

[material][a] property float cutLeafEnabled = 0.0;
[material][a] property float cutLeafDistance = 1.0;

// WIND_ANIMATION
[material][a] property float2 leafOscillationParams = float2(0.0, 0.0); //x: A*sin(T); y: A*cos(T);
[material][a] property float2 trunkOscillationParams = float2(0.0, 0.0);

#if BILLBOARD_FACE_MAIN_CAMERA
    [auto][a] property float4x4 mainCameraInvViewMatrix;
#endif
#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

#if TEXTURE0_SHIFT_ENABLED
    [material][a] property float2 texture0Shift = float2(0, 0);
#endif

#if TEXTURE0_ANIMATION_SHIFT
    [material][a] property float2 tex0ShiftPerSecond = float2(0, 0);
#endif

#if TEXTURE0_ANIMATION_SHIFT
    [auto][a] property float globalTime;
#endif

#if !DRAW_DEPTH_ONLY
    #if SPHERICAL_LIT
        [auto][a] property float speedTreeLightSmoothing;
        [auto][a] property float3 worldViewObjectCenter;
        [auto][a] property float3 boundingBoxSize;

        #if SPHERICAL_HARMONICS_9
            [auto][sh] property float4 sphericalHarmonics[7] : "bigarray";
        #elif SPHERICAL_HARMONICS_4
            [auto][sh] property float4 sphericalHarmonics[3] : "bigarray";
        #else
            [auto][sh] property float4 sphericalHarmonics;
        #endif

        #if PBR_SPEEDTREE
            [auto][a] property float4x4 worldInvTransposeMatrix;

            [material][a] property float3 normalSphereBendCenter = float3(0.0f, 0.0f, 0.0f);
            [material][a] property float normalSphereBendZSquish = 1.0f;
            [material][a] property float normalSphereBendTerm = 0.0f;

            [material][a] property float2 pbrVertexAOBrightnessContrast = float2(0.0f, 1.0f);
            [material][a] property float pbrSHOcclusionMult = 2.0f;
        #else
            [material][a] property float2 vertexAOBrightnessContrast = float2(0.0f, 1.0f);
            [material][a] property float shOcclusionMult = 2.0f;
        #endif
    #else //legacy for old tree lighting
        [material][a] property float4 treeLeafColorMul = float4(0.5,0.5,0.5,0.5);
        [material][a] property float treeLeafOcclusionOffset = 0.0;
        [material][a] property float treeLeafOcclusionMul = 0.5;
    #endif

    #if USE_VERTEX_FOG
        #include "vp-fog-props.slh"
        [auto][a] property float3 cameraPosition;
        #if FOG_ATMOSPHERE
            [auto][a] property float4 lightPosition0;
        #endif
    #endif
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out  output;

    float3 position = lerp(input.position.xyz, input.pivot.xyz, input.pivot.w);
    float3 billboardOffset = input.position.xyz - position.xyz;

    if (cutLeafEnabled != 0.0)
    {
        float pivotDistance = dot(position.xyz, float3(worldViewMatrix[0].z, worldViewMatrix[1].z, worldViewMatrix[2].z)) + worldViewMatrix[3].z;
        billboardOffset *= step(-cutLeafDistance, pivotDistance);
    }

    //inAngleSinCos:          x: cos(T0);  y: sin(T0);
    //leafOscillationParams:  x: A*sin(T); y: A*cos(T);
    float3 windVectorFlex = float3(trunkOscillationParams * input.flexibility, 0.0);
    position += windVectorFlex;

    float2 SinCos = input.angleSinCos * leafOscillationParams; //vec2(A*sin(t)*cos(t0), A*cos(t)*sin(t0))
    float sinT = SinCos.x + SinCos.y;     //sin(t+t0)*A = sin*cos + cos*sin
    float cosT = 1.0 - 0.5 * sinT * sinT; //cos(t+t0)*A = 1 - 0.5*sin^2

    float4 SinCosT = float4(sinT, cosT, cosT, sinT); //temp vec for mul
    float4 offsetXY = float4(billboardOffset.x, billboardOffset.y, billboardOffset.x, billboardOffset.y); //temp vec for mul
    float4 rotatedOffsetXY = offsetXY * SinCosT; //vec4(x*sin, y*cos, x*cos, y*sin)

    billboardOffset.x = rotatedOffsetXY.z - rotatedOffsetXY.w; //x*cos - y*sin
    billboardOffset.y = rotatedOffsetXY.x + rotatedOffsetXY.y; //x*sin + y*cos

    float4 billboardOffsetViewPos = float4(worldScale * billboardOffset, 0.0);
    float4 wPos = mul(float4(position, 1.0), worldMatrix);
    float4 wPosShadow = wPos;
#if BILLBOARD_FACE_MAIN_CAMERA
    wPos += mul(billboardOffsetViewPos, mainCameraInvViewMatrix);
#else
    wPos += mul(billboardOffsetViewPos, invViewMatrix);
#endif

#if SPEEDTREE_JOINT_TRANSFORM
    float4 jointViewOffset = speedtreeJointViewOffsets[int(input.jointIndex)];
    #if SPEEDTREE_JOINT_LENGTHWISE_TRANSFORM
        jointViewOffset.xyz *= length(input.position.xyz - input.pivot.xyz) * jointViewOffset.w;
    #endif
    jointViewOffset.w = 0.0;
#endif

#if RECEIVE_SHADOW
    // we flip offset for better side look
    #if SPEEDTREE_JOINT_TRANSFORM
        wPosShadow -= mul(billboardOffsetViewPos - jointViewOffset, transpose(shadowViewMatrix));
    #else
        wPosShadow -= mul(billboardOffsetViewPos, transpose(shadowViewMatrix));
    #endif
#endif

    float4 eyeCoordsPosition4 = mul(wPos, viewMatrix);

    #if SPEEDTREE_JOINT_TRANSFORM
        eyeCoordsPosition4.xyz += jointViewOffset.xyz;
    #endif

    output.position = mul(eyeCoordsPosition4, projMatrix);
    output.varVertexColor = half4(input.color0);
    output.varTexCoord0.xy = input.texcoord0;

    #if TEXTURE0_SHIFT_ENABLED
        output.varTexCoord0.xy += texture0Shift;
    #endif

    #if TEXTURE0_ANIMATION_SHIFT
        output.varTexCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
    #endif

    #if FORCE_2D_MODE
        output.position.z = 0.0;
    #endif

#if !DRAW_DEPTH_ONLY

    #if USE_VERTEX_FOG
        #if USE_FOG_HALFSPACE
            float3 FOG_world_position = wPos.xyz;
        #endif
        #define FOG_eye_position cameraPosition
        #define FOG_view_position eyeCoordsPosition4.xyz
        #define FOG_in_position input.position
        #define FOG_to_light_dir lightPosition0.xyz
        #include "vp-fog-math.slh"
        output.varFog = half4(FOG_result);
    #endif

    #if SPHERICAL_LIT
        #if SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9
            float3 sphericalLightFactor = 0.282094 * sphericalHarmonics[0].xyz;
        #else
            float3 sphericalLightFactor = 0.282094 * sphericalHarmonics.xyz;
        #endif

        #if SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9
            if (cutLeafEnabled == 0.0)
            {
                float3 localSphericalLightFactor = sphericalLightFactor;
                float3x3 invViewMatrix3 = float3x3(float3(invViewMatrix[0].xyz), float3(invViewMatrix[1].xyz), float3(invViewMatrix[2].xyz));
                float3 normal = mul((eyeCoordsPosition4.xyz - worldViewObjectCenter), invViewMatrix3);
                normal /= boundingBoxSize;
                float3 n = normalize(normal);

                float3x3 shMatrix = float3x3(float3(sphericalHarmonics[0].w,  sphericalHarmonics[1].xy),
                                            float3(sphericalHarmonics[1].zw, sphericalHarmonics[2].x),
                                            float3(sphericalHarmonics[2].yzw));
                sphericalLightFactor += 0.325734 * mul(float3(n.y, n.z, n.x), shMatrix);

                float3 localNormal = mul((worldScale * billboardOffset), invViewMatrix3);
                localNormal.z += 1.0 - input.pivot.w; //in case regular geometry (not billboard) we have zero 'localNoraml', so add something to correct 'normalize'
                float3 ln = normalize(localNormal);
                localSphericalLightFactor += (0.325734 * mul(float3(ln.y, ln.z, ln.x), shMatrix)) * input.pivot.w;

                #if SPHERICAL_HARMONICS_9
                    sphericalLightFactor += (0.273136 * (n.y * n.x)) * float3(sphericalHarmonics[3].xyz);
                    sphericalLightFactor += (0.273136 * (n.y * n.z)) * float3(sphericalHarmonics[3].w,  sphericalHarmonics[4].xy);
                    sphericalLightFactor += (0.078847 * (3.0 * n.z * n.z - 1.0)) * float3(sphericalHarmonics[4].zw, sphericalHarmonics[5].x);
                    sphericalLightFactor += (0.273136 * (n.z * n.x))  * float3(sphericalHarmonics[5].yzw);
                    sphericalLightFactor += (0.136568 * (n.x * n.x - n.y * n.y)) * float3(sphericalHarmonics[6].xyz);
                #endif

                sphericalLightFactor = lerp(sphericalLightFactor, localSphericalLightFactor, speedTreeLightSmoothing);
            }
        #endif // SPHERICAL_HARMONICS_4 || SPHERICAL_HARMONICS_9

        #if PBR_SPEEDTREE
            half aoBrightness = half(pbrVertexAOBrightnessContrast.x);
            half aoContrast = half(pbrVertexAOBrightnessContrast.y);
            half aoMult = half(pbrSHOcclusionMult);
        #else
            half aoBrightness = half(vertexAOBrightnessContrast.x);
            half aoContrast = half(vertexAOBrightnessContrast.y);
            half aoMult = half(shOcclusionMult);
        #endif

         // input.color0.rgb have same values (speedtree baked occlusion)
        half vertexOcclusion = aoContrast * half(input.color0.r - 0.5) + half(0.5) + aoBrightness;

        output.varVertexColor.xyz = half3(sphericalLightFactor) * vertexOcclusion * aoMult;
        output.varVertexColor.a = half(1.0);
    #else // legacy for old tree lighting
        output.varVertexColor.xyz = half3(input.color0.xyz * treeLeafColorMul.xyz * treeLeafOcclusionMul + float3(treeLeafOcclusionOffset,treeLeafOcclusionOffset,treeLeafOcclusionOffset));
        output.varVertexColor.a = input.color0.a;
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        output.projectedPosition = output.position;
    #endif

    #if PBR_SPEEDTREE
        output.worldPos = wPos;
    #endif

    #if RECEIVE_SHADOW
        output.worldPosShadow = wPosShadow;
        float4 shadowViewPos = mul(wPosShadow, shadowViewMatrix);
        output.shadowPos = shadowViewPos.xyz;
    #endif

    #if PBR_SPEEDTREE
        half3 tBasis = half3(mul(float4(input.tangent, 0.0), worldInvTransposeMatrix).xyz);
        half3 bBasis = half3(mul(float4(input.binormal, 0.0), worldInvTransposeMatrix).xyz);
        half3 nBasis = half3(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);

        half3 sphC = half3(mul(float4(normalSphereBendCenter, 1.0), worldMatrix).xyz);
        half3 sphereBendNormal = half3(output.worldPos.xyz) - sphC;
        sphereBendNormal.z *= half(normalSphereBendZSquish);
        sphereBendNormal = normalize(sphereBendNormal);

        half3 bentNormal = normalize(lerp(nBasis, sphereBendNormal, half(normalSphereBendTerm)));

        half3 tProjN = bentNormal * dot(tBasis, bentNormal);
        half3 bentTangent = normalize(tBasis - tProjN);

        float3 bProjN = float3(bentNormal) * dot(float3(bBasis), float3(bentNormal));
        float3 bProjT = float3(bentTangent) * dot(float3(bBasis), float3(bentTangent));

        half3 bentBinormal = half3(normalize(float3(bBasis) - bProjN - bProjT));

        output.tangentToWorld0 = half3(bentTangent.x, bentBinormal.x, bentNormal.x);
        output.tangentToWorld1 = half3(bentTangent.y, bentBinormal.y, bentNormal.y);
        output.tangentToWorld2 = half3(bentTangent.z, bentBinormal.z, bentNormal.z);
    #endif
#elif LOD_TRANSITION
    output.projectedPosition = output.position;
#endif

    return output;
}
