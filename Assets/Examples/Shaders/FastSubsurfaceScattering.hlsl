#ifndef FASTSSS_INCLUDED
#define FASTSSS_INCLUDED

void FastSSS_float(in float3 lightDirWS, in float3 normalWS, in float3 viewDirWS, in float3 colorScatter, in float backDiffuse, out float3 color)
{
#if SHADERGRAPH_PREVIEW
   color = float3(1.0, 0.3, 0.0);
#else
   float vl = saturate(dot(viewDirWS, -normalize(lightDirWS + normalWS*(1-backDiffuse))));
   color = vl * colorScatter;
#endif
}

#endif