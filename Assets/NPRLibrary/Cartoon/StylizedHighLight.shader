///
///  Reference: 	Anjyo K, Hiramitsu K. Stylized highlights for cartoon rendering and animation[J]. 
///						Computer Graphics and Applications, IEEE, 2003, 23(4): 54-61.
/// 
Shader "AspectURP/NPR/Stylized Highlights" {
	Properties {
		_Color ("Diffuse Color", Color) = (1, 1, 1, 1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {}
		_Outline ("Outline", Range(0,1)) = 0.1
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SpecularScale ("Specular Scale", Range(0, 0.05)) = 0.01
		_TranslationX ("Translation X", Range(-1, 1)) = 0
		_TranslationY ("Translation Y", Range(-1, 1)) = 0
		_RotationX ("Rotation X", Range(-180, 180)) = 0
		_RotationY ("Rotation Y", Range(-180, 180)) = 0
		_RotationZ ("Rotation Z", Range(-180, 180)) = 0
		_ScaleX ("Scale X", Range(-1, 1)) = 0
		_ScaleY ("Scale Y", Range(-1, 1)) = 0
		_SplitX ("Split X", Range(0, 1)) = 0
		_SplitY ("Split Y", Range(0, 1)) = 0
		_SquareN ("Square N", Range(1, 10)) = 1
		_SquareScale ("Square Scale", Range(0, 1)) = 0
	}
	SubShader {
		Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
		LOD 200
		
		//UsePass "NPR/Cartoon/Antialiased Cel Shading/OUTLINE"
		
		Pass {
			Tags
            {
                "LightMode"="UniversalForward"
                "RenderType"="Opaque"
            }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma glsl
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			#define DegreeToRadian 0.0174533
			
			half4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			half4 _Specular;
			half _SpecularScale;
			float _TranslationX;
			float _TranslationY;
			float _RotationX;
			float _RotationY;
			float _RotationZ;
			float _ScaleX;
			float _ScaleY;
			float _SplitX;
			float _SplitY;
			float _SquareN;
			half _SquareScale;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			}; 
			
			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
				float3 tangentNormal : TEXCOORD1;
				float3 tangentLightDir : TEXCOORD2;
				float3 tangentViewDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
			};
			
			v2f vert (a2v v) {
				v2f o;
								
				o.pos = TransformObjectToHClip( v.vertex);
				//TANGENT_SPACE_ROTATION;
				o.tangentNormal  = mul(rotation, v.normal); // Equal to (0, 0, 1)
				o.tangentLightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
				o.tangentViewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			float4 frag(v2f i) : COLOR { 
                Light mainLight = GetMainLight();
                float atten = mainLight.distanceAttenuation;


				half3 tangentNormal = normalize(i.tangentNormal);
				half3 tangentLightDir = normalize(i.tangentLightDir);
				half3 tangentViewDir = normalize(i.tangentViewDir);
				half3 tangentHalfDir = normalize(tangentViewDir + tangentLightDir);
					
				// Scale
				tangentHalfDir = tangentHalfDir - _ScaleX * tangentHalfDir.x * half3(1, 0, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				tangentHalfDir = tangentHalfDir - _ScaleY * tangentHalfDir.y * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Ratation
				float xRad = _RotationX * DegreeToRadian;
				float3x3 xRotation = float3x3(1, 0, 0,
													 0, cos(xRad), sin(xRad),
													 0, -sin(xRad), cos(xRad));
				float yRad = _RotationY * DegreeToRadian;
				float3x3 yRotation = float3x3(cos(yRad), 0, -sin(yRad),
													 0, 1, 0,
													 sin(yRad), 0, cos(yRad));
				float zRad = _RotationZ * DegreeToRadian;
				float3x3 zRotation = float3x3(cos(zRad), sin(zRad), 0,
													 -sin(zRad), cos(zRad), 0,
													 0, 0, 1);								
				tangentHalfDir = mul(zRotation, mul(yRotation, mul(xRotation, tangentHalfDir)));
				
				// Translation
				tangentHalfDir = tangentHalfDir + half3(_TranslationX, _TranslationY, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Split
				half signX = 1;
				if (tangentHalfDir.x < 0) {
					signX = -1;
				}
				half signY = 1;
				if (tangentHalfDir.y < 0) {
					signY = -1;
				}
				tangentHalfDir = tangentHalfDir - _SplitX * signX * half3(1, 0, 0) - _SplitY * signY * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Square
				float sqrThetaX = acos(tangentHalfDir.x);
				float sqrThetaY = acos(tangentHalfDir.y);
				half sqrnormX = sin(pow(2 * sqrThetaX, _SquareN));
				half sqrnormY = sin(pow(2 * sqrThetaY, _SquareN));
				tangentHalfDir = tangentHalfDir - _SquareScale * (sqrnormX * tangentHalfDir.x * half3(1, 0, 0) + sqrnormY * tangentHalfDir.y * half3(0, 1, 0));
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Compute the lighting model
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				//UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				half diff =  dot (tangentNormal, tangentLightDir);
				diff = diff * 0.5 + 0.5;
				
				half4 c = tex2D (_MainTex, i.uv);
				half3 diffuseColor = c.rgb * _Color.rgb;
				half3 diffuse = _LightColor0.rgb * diffuseColor * tex2D(_Ramp, float2(diff, diff)).rgb;
				
				half spec = dot(tangentNormal, tangentHalfDir);
				half w = fwidth(spec) * 1.0;
				half3 specular = lerp(half3(0, 0, 0), _Specular.rgb, smoothstep(-w, w, spec + _SpecularScale - 1));
				
				return half4(ambient + (diffuse + specular) * atten, 1.0);
			} 
			
			ENDCG
		}
		/*
		Pass {
			Tags { "LightMode"="ForwardAdd" }
			
			Blend One One
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_fwdadd
			
			#pragma glsl
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			#define DegreeToRadian 0.0174533
			
			half4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			half4 _Specular;
			half _SpecularScale;
			float _TranslationX;
			float _TranslationY;
			float _RotationX;
			float _RotationY;
			float _RotationZ;
			float _ScaleX;
			float _ScaleY;
			float _SplitX;
			float _SplitY;
			float _SquareN;
			half _SquareScale;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			}; 
			
			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
				float3 tangentNormal : TEXCOORD1;
				float3 tangentLightDir : TEXCOORD2;
				float3 tangentViewDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
				SHADOW_COORDS(5)
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos( v.vertex);
				TANGENT_SPACE_ROTATION;
				o.tangentNormal  = mul(rotation, v.normal); // Equal to (0, 0, 1)
				o.tangentLightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
				o.tangentViewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			float4 frag(v2f i) : COLOR { 
				half3 tangentNormal = normalize(i.tangentNormal);
				half3 tangentLightDir = normalize(i.tangentLightDir);
				half3 tangentViewDir = normalize(i.tangentViewDir);
				half3 tangentHalfDir = normalize(tangentViewDir + tangentLightDir);
				
				// Scale
				tangentHalfDir = tangentHalfDir - _ScaleX * tangentHalfDir.x * half3(1, 0, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				tangentHalfDir = tangentHalfDir - _ScaleY * tangentHalfDir.y * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Ratation
				float xRad = _RotationX * DegreeToRadian;
				float3x3 xRotation = float3x3(1, 0, 0,
													 0, cos(xRad), sin(xRad),
													 0, -sin(xRad), cos(xRad));
				float yRad = _RotationY * DegreeToRadian;
				float3x3 yRotation = float3x3(cos(yRad), 0, -sin(yRad),
													 0, 1, 0,
													 sin(yRad), 0, cos(yRad));
				float zRad = _RotationZ * DegreeToRadian;
				float3x3 zRotation = float3x3(cos(zRad), sin(zRad), 0,
													 -sin(zRad), cos(zRad), 0,
													 0, 0, 1);						
				tangentHalfDir = mul(zRotation, mul(yRotation, mul(xRotation, tangentHalfDir)));
				
				// Translation
				tangentHalfDir = tangentHalfDir + half3(_TranslationX, _TranslationY, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Split
				half signX = 1;
				if (tangentHalfDir.x < 0) {
					signX = -1;
				}
				half signY = 1;
				if (tangentHalfDir.y < 0) {
					signY = -1;
				}
				tangentHalfDir = tangentHalfDir - _SplitX * signX * half3(1, 0, 0) - _SplitY * signY * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				
				// Square
				float sqrThetaX = acos(tangentHalfDir.x);
				float sqrThetaY = acos(tangentHalfDir.y);
				half sqrnormX = sin(pow(2 * sqrThetaX, _SquareN));
				half sqrnormY = sin(pow(2 * sqrThetaY, _SquareN));
				tangentHalfDir = tangentHalfDir - _SquareScale * (sqrnormX * tangentHalfDir.x * half3(1, 0, 0) + sqrnormY * tangentHalfDir.y * half3(0, 1, 0));
				tangentHalfDir = normalize(tangentHalfDir);
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				half diff =  dot (tangentNormal, tangentLightDir);
				diff = diff * 0.5 + 0.5;
				
				half4 c = tex2D (_MainTex, i.uv);
				half3 diffuseColor = c.rgb * _Color.rgb;
				half3 diffuse = _LightColor0.rgb * diffuseColor * tex2D(_Ramp, float2(diff, diff)).rgb;
				
				half spec = dot(tangentNormal, tangentHalfDir);
				half w = fwidth(spec) * 1.0;
				half3 specular = lerp(half3(0, 0, 0), _Specular.rgb, smoothstep(-w, w, spec + _SpecularScale - 1));
				
				return half4((diffuse + specular) * atten, 1.0);
			}
			
			ENDCG
		}*/
	}
	//FallBack "Diffuse"
}
