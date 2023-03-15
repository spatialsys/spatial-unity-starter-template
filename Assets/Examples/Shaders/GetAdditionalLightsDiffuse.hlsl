#ifndef GETADDITIONALLIGHTSDIFFUSE_INCLUDED
#define GETADDITIONALLIGHTSDIFFUSE_INCLUDED
 
void AdditionalLightsDiffuse_float(float3 positionWS, float3 normalWS, out float3 diffuse)
{
#if SHADERGRAPH_PREVIEW
   diffuse = float3(0.5, 0.5, 0);
#else
   uint numAdditionalLights = GetAdditionalLightsCount();
   for (uint l = 0; l < numAdditionalLights; l++) {
      Light light = GetAdditionalLight(l, positionWS);
      float3 radiance = light.color * (light.distanceAttenuation * light.shadowAttenuation);
      float currentDiffuse = saturate(dot(normalize(normalWS), light.direction));
      diffuse += currentDiffuse * radiance;
   }
#endif
}
 
#endif