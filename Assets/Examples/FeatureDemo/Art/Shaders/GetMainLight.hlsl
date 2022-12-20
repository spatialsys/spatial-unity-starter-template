#ifndef GETMAINLIGHT_INCLUDED
#define GETMAINLIGHT_INCLUDED
 
void MainLight_float(float3 worldPos, float4 screenPos, out float3 lightDir, out float3 color, out float distanceAtten, out float shadowAtten)
{
#if SHADERGRAPH_PREVIEW
   lightDir = float3(0.5, 0.5, 0);
   color = 1;
   distanceAtten = 1;
   shadowAtten = 1;
#else
#if SHADOWS_SCREEN
//    float4 clipPos = TransformWorldToHClip(worldPos);
//    float4 shadowCoord = ComputeScreenPos(clipPos);
   float4 shadowCoord = screenPos;
#else
   float4 shadowCoord = TransformWorldToShadowCoord(worldPos);
#endif
   Light mainLight = GetMainLight(shadowCoord);
   lightDir = mainLight.direction;
   color = mainLight.color;
   distanceAtten = mainLight.distanceAttenuation;
   shadowAtten = mainLight.shadowAttenuation;
#endif
}

// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
// #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"
 
// void GetSun_float(out float3 lightDir, out float3 color)
// {
// #if SHADERGRAPH_PREVIEW
//     lightDir = float3(0.707, 0.707, 0);
//     color = 1;
// #else
//     if (_DirectionalLightCount > 0)
//     {
//         DirectionalLightData light = _DirectionalLightDatas[0];
//         lightDir = -light.forward.xyz;
//         color = light.color;
//     }
//     else
//     {
//         lightDir = float3(1, 0, 0);
//         color = 0;
//     }
// #endif
// }
 
#endif