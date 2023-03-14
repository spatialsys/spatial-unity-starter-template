Shader "Spatial/Environment/MainSurface"
{
    Properties
    {
        [Header(Surface)]
        _BaseColor ("Base color", Color) = (1, 1, 1, 1)
        _ColorMultiply ("Color multiply (for non-blurred version)", Color) = (1, 1, 1, 1)
        _BaseMap ("Texture", 2D) = "white" {}
        _BumpMap ("Bump Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        _BumpScaleTransparent ("Bump Scale (Only for Transparent)", Float) = 1
        _SpecularPower ("Specular Power", Float) = 15
        _SpecularIntensity ("Specular Intensity (Only for transparent)", Range(0,1)) = 1

        [Header(Reflection)]
        _FresnelIntensity("Fresnel Intensity", Range(0,1)) = 0.5
        _ReflectionIntensity("Reflection Intensity", Range(0,1)) = 1
        _ReflectionFresnelPow("Reflection Fresnel Power", Float) = 1
        _ReflectionRoughness("Reflection Roughness", Range(0.0, 10.0)) = 0.0

        [Space(10)]
        [Header(Blur)]
        // Global Keyword from Spatial. Enable below only when testing.
        [Toggle(_USE_BLUR)] _UseBlur ("Use Blur Effect", Float) = 0
        // [Toggle(_USE_CAMERA_COLOR_TEXTURE)] _UseCameraColorTexture ("Use camera color texture", Float) = 0
        [Header(MultiSampling)]
        _CameraOpaqueTextureDown ("Camera Color Texture Down Sampled", 2D) = "white" {}
        _BlurAmount ("Blur Amount", Float) = 2
        _BlurIterations ("Blur Iterations", Range(2,6)) = 4
        _BlurDistribution ("Blur Distribution", Range(0,1)) = 0.8

        [Header(DownSampling)]
        [Toggle(_USE_DOWNSAMPLING)] _UseDownSampling ("Use down sampling", Float) = 0
        _DownSampleIterations ("Down Sample Iterations", Range(2,8)) = 4
        _DownSampleOffset ("Down Sample Offset", Int) = 0
        _DownSampleDistribution ("Down Sample Distribution", Range(0,2)) = 1
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "Queue" = "Transparent" // Color texture is rendered after the queue "2500"
            "RenderPipeline" = "UniversalPipeline"
        }
        // Blend One OneMinusSrcAlpha // Premultiply
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            // Global Keywords that Spatial provides
            #pragma shader_feature_local _ _USE_BLUR
            #pragma multi_compile _ _USE_CAMERA_COLOR_TEXTURE

            // Downsampling is Spatial Internal SDK feature, so we need to wait 6.52 to be released.
            // TODO: Remove below once we released 6.52.
            // #pragma multi_compile _ _USE_DOWNSAMPLING

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                half4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varying
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                half3 positionWS : TEXCOORD3;
                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    float4 screenPos : TEXCOORD5;
                #endif
                float fogCoord : TEXCOORD4;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                TEXTURE2D(_CameraOpaqueTexture);
                SAMPLER(sampler_CameraOpaqueTexture);
                #if defined(_USE_DOWNSAMPLING)
                    TEXTURE2D(_CameraOpaqueTextureDown);
                    SAMPLER(sampler_CameraOpaqueTextureDown);
                #endif
            #endif

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ColorMultiply;
                float4 _BaseMap_ST;
                float4 _BumpMap_ST;
                half _BumpScale;
                half _BumpScaleTransparent;
                half _SpecularPower;
                half _SpecularIntensity;

                half _FresnelIntensity;
                half _ReflectionIntensity;
                half _ReflectionFresnelPow;
                half _ReflectionRoughness;

                half _BlurAmount;
                int _BlurIterations;
                half _BlurDistribution;

                int _DownSampleIterations;
                int _DownSampleOffset;
                half _DownSampleDistribution;
            CBUFFER_END

            Varying vert (Attributes IN)
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                Varying OUT = (Varying)0;
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;

                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    OUT.screenPos = vertexInput.positionNDC;
                #endif

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS);
                OUT.normalWS = normalInput.normalWS;

                real sign = IN.tangentOS.w * GetOddNegativeScale();
                OUT.tangentWS = half4(normalInput.tangentWS.xyz, sign);

                OUT.uv.xy = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.uv.zw = TRANSFORM_TEX(IN.uv, _BumpMap);

                OUT.fogCoord = ComputeFogFactor(OUT.positionCS.z);

                return OUT;
            }

            half4 frag (Varying IN) : SV_Target
            {
                half4 color = _BaseColor;
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv.zw));
                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    half bumpScale = _BumpScale;
                #else
                    half bumpScale = _BumpScaleTransparent;
                #endif
                normalTS = half3(normalTS.xy * bumpScale, lerp(1, normalTS.z, bumpScale));
                
                float sgn = IN.tangentWS.w;      // should be either +1 or -1
                float3 bitangent = sgn * cross(IN.normalWS.xyz, IN.tangentWS.xyz);
                half3x3 tangentToWorld = half3x3(IN.tangentWS.xyz, bitangent.xyz, IN.normalWS.xyz);
                half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS.xyz);

                Light mainLight = GetMainLight();
                
                // Diffuse
                // half NoL = dot(normalWS, mainLight.direction);
                // half3 diffuse = saturate(NoL) * mainLight.color.rgb * mainLight.distanceAttenuation;
                // color.rgb *= diffuse;

                // Ambient
                // half3 ambient = SampleSH(normalWS);
                // color.rgb += ambient;

                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    float2 uv = IN.screenPos.xy / IN.screenPos.w;
                    uv += normalTS.xy;

                    half3 cameraColor = (half3)0;

                    #if defined(_USE_DOWNSAMPLING)
                        half distribute = 40;
                        half distributeSum = 0;
                        for(int i=0; i<_DownSampleIterations; i++)
                        {
                            distributeSum += distribute;
                            cameraColor += SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTextureDown, sampler_CameraOpaqueTextureDown, uv, _DownSampleOffset+i) * distribute;
                            distribute *= _DownSampleDistribution;
                        }
                        cameraColor /= distributeSum;
                    #else
                        float offsetx = _BlurAmount / _ScreenParams.x;
                        float offsety = _BlurAmount / _ScreenParams.y;
                        half distribute = 40;
                        half distributeSum = distribute;
                        cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv) * distribute;
                        for(int i=1; i<_BlurIterations; i++)
                        {
                            float ox = offsetx * i;
                            float oy = offsety * i;

                            distribute *= _BlurDistribution;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(ox, 0)).rgb * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv - half2(ox, 0)).rgb * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(0, oy)).rgb * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv - half2(0, oy)).rgb * distribute;
                            distributeSum += distribute * 4;

                            distribute *= _BlurDistribution;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(ox, oy)) * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(-ox, oy)) * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(ox, -oy)) * distribute;
                            cameraColor += SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv + half2(-ox, -oy)) * distribute;
                            distributeSum += distribute * 4;
                        }
                        cameraColor /= distributeSum;
                    #endif

                    color.rgb *= cameraColor.rgb;
                    color.a = 1;
                #else // !_USE_CAMERA_COLOR_TEXTURE
                    color.rgb *= _ColorMultiply.rgb;
                    color.rgb *= SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv.xy).rgb;
                    color.a = saturate(color.a + _ColorMultiply.a);
                    // color.rgb *= color.a; // Premultiply
                #endif

                // Specular
                half3 h = normalize(mainLight.direction + viewDirWS);
                half NoH = dot(normalWS, h);
                half3 specular = saturate(NoH);// * mainLight.color.rgb * mainLight.distanceAttenuation;
                specular = pow(specular, _SpecularPower);
                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    color.rgb += specular;
                #else
                    color.rgb += specular * _SpecularIntensity;
                #endif

                // Reflection
                float3 reflectWS = reflect(-viewDirWS, normalWS);
                half4 skyData = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectWS, _ReflectionRoughness);
                half3 skyColor = DecodeHDREnvironment(skyData, unity_SpecCube0_HDR);

                half NoV = dot(normalWS, viewDirWS);
                half fresnel = pow(saturate(1-NoV), _ReflectionFresnelPow) * _FresnelIntensity;
                #if defined(_USE_BLUR) && defined(_USE_CAMERA_COLOR_TEXTURE)
                    color.rgb += skyColor.rgb * fresnel * _ReflectionIntensity;
                    // color.rgb += skyColor.rgb * (fresnel + specular) * _ReflectionIntensity;                    
                #else
                    color.rgb += skyColor.rgb * _ReflectionIntensity;
                    color.rgb += fresnel;
                #endif

                color.rgb = MixFog(color.rgb, IN.fogCoord);

                return color;
            }
            ENDHLSL
        }
    }
}