#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#ensuredefined HIGHLIGHT_WAVE_ANIM 0

#include "lighting.slh"
#include "vp-fog-props.slh"

#if !PIXEL_LIT && NORMALIZED_BLINN_PHONG
    #include "fresnel-shlick.slh"
#endif

vertex_in
{
    float3 position : POSITION;
    float3 normal : NORMAL;

    #if MATERIAL_TEXTURE
        float2 texcoord0 : TEXCOORD0;
    #endif

    #if MATERIAL_DECAL || ALPHA_MASK || USE_VERTEX_DISPLACEMENT
        float2 texcoord1 : TEXCOORD1;
    #endif

    #if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
        float4 color0 : COLOR0;
    #endif

    #if PIXEL_LIT
        float3 tangent : TANGENT;
        float3 binormal : BINORMAL;
    #endif

    #include "skinning-vertex-input.slh"
};

vertex_out
{
    float4 position : SV_POSITION;

    #if MATERIAL_TEXTURE || TILED_DECAL_MASK
        float4 varTexCoord0 : TEXCOORD0; // packed. xy - texcoord. zw - decal tile texcoord
    #endif

    #if MATERIAL_DECAL || ALPHA_MASK
        float2 varTexCoord1 : TEXCOORD1;
    #endif

    #if MATERIAL_DETAIL
        float2 varDetailTexCoord : TEXCOORD2;
    #endif

    #if PIXEL_LIT
        float4 tangentToView0 : NORMAL1; // here we are storing transposed (T, B, N) matrix
        float4 tangentToView1 : NORMAL2; // used for transforming normal from tangent space to view space
        float4 tangentToView2 : NORMAL3; // in .w components position in view-space is stored

        #if RECEIVE_SHADOW
            float3 tangentToWorld0 : TANGENTTOWORLD0;
            float3 tangentToWorld1 : TANGENTTOWORLD1;
            float3 tangentToWorld2 : TANGENTTOWORLD2;
        #endif
        
        [lowp] half4 varToLightVec : COLOR1; // in .w decalTextureIndex stored
        float3 varToCameraVec : TEXCOORD7;
    #else
        [lowp] half4 varDiffuseColor : COLOR0; // in .w decalTextureIndex stored
        #if SIMPLE_BLINN_PHONG
            [lowp] half varSpecularColor : TEXCOORD4;
        #elif NORMALIZED_BLINN_PHONG
            [lowp] half4 varSpecularColor : TEXCOORD4;
        #endif
        #if RECEIVE_SHADOW
            float4 worldNormalNdotL : COLOR3;
        #endif
    #endif
    
    #if VERTEX_COLOR
        [lowp] half4 varVertexColor : COLOR1;
    #endif

    #if USE_VERTEX_FOG
        [lowp] half4 varFog : TEXCOORD5;
    #endif

    #if (ENVIRONMENT_MAPPING && (!ENVIRONMENT_MAPPING_NORMALMAP))
        float3 reflectionVector : TEXCOORD6;
    #endif
    #if RECEIVE_SHADOW || LOD_TRANSITION
        float4 projectedPosition : POSITION2;
    #endif
    #if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
        float4 worldPos : POSITION3;
    #endif
    #if RECEIVE_SHADOW
        float3 shadowPos : COLOR5;
    #endif

    #if TILED_DECAL_MASK && TILED_DECAL_ANIMATED_EMISSION
        [lowp] half4 aniCamoParams : COLOR2;
    #endif
    #if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
        [lowp] half3 localPos : POSITION1;
    #endif
};

[auto][a] property float4x4 viewMatrix;
#if RECEIVE_SHADOW || ENVIRONMENT_MAPPING
    [auto][a] property float4x4 worldInvTransposeMatrix;
#endif

#if RECEIVE_SHADOW
    [auto][a] property float4x4 shadowViewMatrix;
#endif

[auto][a] property float4x4 worldViewProjMatrix;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

#if DISTANCE_ATTENUATION
    [material][a] property float lightIntensity0 = 1.0;
#endif

[auto][a] property float4 lightPosition0;

#if !PIXEL_LIT
    [material][a] property float materialSpecularShininess = 0.5;
    [material][a] property float inSpecularity = 1.0;
    [material][a] property float inGlossiness = 0.5;
    [material][a] property float3 metalFresnelReflectance = float3(0.5, 0.5, 0.5);
    [auto][a] property float3 lightColor0;
    [auto][a] property float4x4 pointLights; // 0,1:(position, radius); 2:3 (color, unused)
#endif

#if MATERIAL_DETAIL
    [material][a] property float2 detailTileCoordScale = float2(1.0, 1.0);
#endif

#if TEXTURE0_SHIFT_ENABLED
    [material][a] property float2 texture0Shift = float2(0,0);
#endif

#if TEXTURE0_ANIMATION_SHIFT
    [material][a] property float2 tex0ShiftPerSecond = float2(0,0);
#endif

#if USE_VERTEX_FOG || ENVIRONMENT_MAPPING
    [auto][a] property float3 cameraPosition;
#endif

#if MULTIPLE_DECAL_TEXTURES
    [material][a] property float4 jointToDecalTextureMapping;
#endif

#if TILED_DECAL_MASK && TILED_DECAL_ANIMATED_EMISSION
    [material][a] property float aniCamoPower = 1.0;
    [material][a] property float aniCamoSpeed = 1.0;
    [material][a] property float aniCamoAmplitude = 0.5;
    [material][a] property float aniCamoMiddle = 0.5;
    [material][a] property float aniCamoWidth = 0.1;
    [material][a] property float aniCamoSmooth = 0.3;
    [material][a] property float aniCamoWaveSpeed = 2.0;
    [material][a] property float aniCamoWaveLength = 1.0;
#endif

#define NEED_CHAIN_TEXCOORD_OFFSETS 1
#if INSTANCED_CHAIN
    #include "instanced-chain.slh"
#endif

vertex_out vp_main(vertex_in input)
{
    vertex_out output;

    #include "materials-vertex-processing.slh"

    float3 eyeCoordsPosition = mul(worldPosition, viewMatrix).xyz;
    float3 toLightDir = lightPosition0.xyz - eyeCoordsPosition * lightPosition0.w;

    #if !PIXEL_LIT
        float3 normal = input.normal;

        #if INSTANCED_CHAIN
            normal.yz = Rotate(normal.yz, segmentDirection.y, segmentDirection.x);
            normal = normalize(normal);
        #elif SOFT_SKINNING
            normal = SoftSkinnedNormal(normal, input.indices, input.weights);
        #elif HARD_SKINNING
            normal = HardSkinnedNormal(normal, input.index);
        #endif

        normal = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz); // normal in eye coordinates

        #if DISTANCE_ATTENUATION
            float attenuation = lightIntensity0;
            float distAttenuation = length(toLightDir);
            attenuation /= (distAttenuation * distAttenuation); // use inverse distance for distance attenuation
        #endif

        toLightDir = normalize(toLightDir);

        float NdotL = max(0.0, dot(normal, toLightDir));
        #if RECEIVE_SHADOW
            float3 worldNormal = normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);
            output.worldNormalNdotL = float4(worldNormal.xyz, NdotL);
        #endif

        #if SIMPLE_BLINN_PHONG
            output.varDiffuseColor.rgb = half3(NdotL, NdotL, NdotL);

            // Blinn-phong reflection
            float3 toCameraDir = normalize(-eyeCoordsPosition);
            float3 H = normalize(toLightDir + toCameraDir);
            float nDotHV = max(0.0, dot(normal, H));
            output.varSpecularColor = pow(nDotHV, materialSpecularShininess);
        #elif NORMALIZED_BLINN_PHONG
            float3 toCameraNormalized = normalize(-eyeCoordsPosition);
            float3 H = normalize(toLightDir + toCameraNormalized);

            float NdotH = max(dot(normal, H), 0.0);
            float LdotH = max(dot(toLightDir, H), 0.0);
            float NdotV = max(dot(normal, toCameraNormalized), 0.0);

            float3 fresnelOut  = FresnelShlickVec3(NdotV, metalFresnelReflectance);
            float  specularity = inSpecularity;

            float Dbp = NdotL;
            float Geo = 1.0 / LdotH * LdotH;

            output.varDiffuseColor.rgb =  half3(lightColor0) * (NdotL / _PI);
            output.varSpecularColor.rgb = half3(Dbp * Geo * fresnelOut * specularity);
            output.varSpecularColor.w = half(NdotH);

            #if (MAX_POINT_LIGHTS > 0)
            {
                float3 light = ApplyLight(pointLights[0], pointLights[2], eyeCoordsPosition, normal);
                output.varDiffuseColor.rgb += half3(light);
                #if (MAX_POINT_LIGHTS > 1)
                    light = ApplyLight(pointLights[1], pointLights[3], eyeCoordsPosition, normal);
                    output.varDiffuseColor.rgb += half3(light);
                #endif
            }
            #endif
        #endif
    #endif

    #if PIXEL_LIT
        float3 normal = input.normal;
        float3 tangent = input.tangent;
        float3 binormal = input.binormal;

        #if INSTANCED_CHAIN
            normal.yz = Rotate(normal.yz, segmentDirection.y, segmentDirection.x);
            tangent.yz = Rotate(tangent.yz, segmentDirection.y, segmentDirection.x);
            binormal.yz = Rotate(binormal.yz, segmentDirection.y, segmentDirection.x);

            normal = normalize(normal);
            tangent = normalize(tangent);
            binormal = normalize(binormal);
        #endif

        #if SOFT_SKINNING
            float3x3 tbn = SoftSkinnedTBN(tangent, binormal, normal, input.indices, input.weights);
            tangent = tbn[0];
            binormal = tbn[1];
            normal = tbn[2];
        #elif HARD_SKINNING
            float3x3 tbn = HardSkinnedTBN(tangent, binormal, normal, input.index);
            tangent = tbn[0];
            binormal = tbn[1];
            normal = tbn[2];
        #endif

        float3 t = normalize(mul(float4(tangent, 0.0), worldViewInvTransposeMatrix).xyz);
        float3 b = normalize(mul(float4(binormal, 0.0), worldViewInvTransposeMatrix).xyz);
        float3 n = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);

        output.tangentToView0 = float4(t.x, b.x, n.x, eyeCoordsPosition.x);
        output.tangentToView1 = float4(t.y, b.y, n.y, eyeCoordsPosition.y);
        output.tangentToView2 = float4(t.z, b.z, n.z, eyeCoordsPosition.z);
        
        // transform light and half angle vectors by tangent basis
        float3 toLightTangent;
        toLightTangent.x = dot(toLightDir, t);
        toLightTangent.y = dot(toLightDir, b);
        toLightTangent.z = dot(toLightDir, n);

        float3 toCameraDir = -eyeCoordsPosition;
        float3 toCameraTangent;
        toCameraTangent.x = dot(toCameraDir, t);
        toCameraTangent.y = dot(toCameraDir, b);
        toCameraTangent.z = dot(toCameraDir, n);

        output.varToLightVec.xyz = half3(toLightTangent);
        output.varToCameraVec = float3(toCameraTangent);

        #if RECEIVE_SHADOW
            t = normalize(mul(float4(tangent, 0.0), worldInvTransposeMatrix).xyz);
            b = normalize(mul(float4(binormal, 0.0), worldInvTransposeMatrix).xyz);
            n = normalize(mul(float4(normal, 0.0), worldInvTransposeMatrix).xyz);

            output.tangentToWorld0 = float3(t.x, b.x, n.x);
            output.tangentToWorld1 = float3(t.y, b.y, n.y);
            output.tangentToWorld2 = float3(t.z, b.z, n.z);
        #endif

    #endif // PIXEL_LIT

    #if USE_VERTEX_FOG
        #define FOG_eye_position cameraPosition
        #define FOG_view_position eyeCoordsPosition
        #define FOG_in_position input.position
        #define FOG_to_light_dir toLightDir
        #define FOG_world_position worldPosition
        #include "vp-fog-math.slh"
        output.varFog = half4(FOG_result);
    #endif

    #if VERTEX_COLOR
        output.varVertexColor = half4(input.color0);
    #endif

    #if MATERIAL_TEXTURE || TILED_DECAL_MASK
        output.varTexCoord0.xy = input.texcoord0;

        #if INSTANCED_CHAIN
            const float texCoordScale = segmentLength / chunkLength;
            const float texCoordOffset = GetTexCoordOffset(instanceId + 1);
            output.varTexCoord0.y = texCoordOffset + texCoordScale * output.varTexCoord0.y;
        #endif

        output.varTexCoord0.xy = ApplyTex0CoordsTransform(output.varTexCoord0.xy);
    #endif

    #if MATERIAL_TEXTURE
        #if TEXTURE0_SHIFT_ENABLED
            output.varTexCoord0.xy += texture0Shift;
        #endif

        #if TEXTURE0_ANIMATION_SHIFT
            output.varTexCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
        #endif
    #endif

    #if TILED_DECAL_MASK 
        float2 resDecalTexCoord = output.varTexCoord0.xy * decalTileCoordScale;  
        #if TILED_DECAL_TRANSFORM
            #if HARD_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransformHardSkin(resDecalTexCoord, input.index);
            #elif !SOFT_SKINNING
                resDecalTexCoord = ApplyTex1CoordsTransform(resDecalTexCoord);
            #endif
        #endif
        output.varTexCoord0.zw = resDecalTexCoord;

        #if TILED_DECAL_ANIMATED_EMISSION
            float windowOffset = aniCamoAmplitude * sin(globalTime * aniCamoSpeed);
            output.aniCamoParams.x = aniCamoMiddle - 0.5 * aniCamoWidth + windowOffset - aniCamoSmooth;
            output.aniCamoParams.y = aniCamoMiddle + 0.5 * aniCamoWidth + windowOffset;
            output.aniCamoParams.z = 1.0 / aniCamoSmooth;
            output.aniCamoParams.xy *= output.aniCamoParams.z;
            output.aniCamoParams.w = aniCamoPower * 0.5 * (1.0 + cos(input.position.y * aniCamoWaveLength + globalTime * aniCamoWaveSpeed));
        #endif
    #endif

    #if MATERIAL_DETAIL
        output.varDetailTexCoord = output.varTexCoord0.xy * detailTileCoordScale;
    #endif

    #if MATERIAL_DECAL || ALPHA_MASK
        output.varTexCoord1 = input.texcoord1.xy;
    #endif

    #if FORCE_2D_MODE
        output.position.z = 0.0;
    #endif

    #if RECEIVE_SHADOW || LOD_TRANSITION
        output.projectedPosition = output.position;
    #endif

    #if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
        output.worldPos = worldPosition;
    #endif

    #if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
        output.localPos = half3(localPosition);
    #endif

    #if RECEIVE_SHADOW
        float4 shadowViewPos = mul(worldPosition, shadowViewMatrix);
        output.shadowPos = shadowViewPos.xyz;
    #endif

    #if (ENVIRONMENT_MAPPING && (!ENVIRONMENT_MAPPING_NORMALMAP))
        float3 wsNormal = normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);
        float3 wsView = normalize(worldPosition.xyz - cameraPosition);
        output.reflectionVector = reflect(wsView, wsNormal);
    #endif

    #if MULTIPLE_DECAL_TEXTURES
        const int jointIndex = int(clamp(input.index, 0.0f, 3.0f));
        #if PIXEL_LIT
            output.varToLightVec.w = half(jointToDecalTextureMapping[jointIndex]);
        #else
            output.varDiffuseColor.w = half(jointToDecalTextureMapping[jointIndex]);
        #endif
    #endif

    return output;
}
