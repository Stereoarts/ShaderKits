Shader "ShaderKits/Standard Edge"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_SpecColor("Specular", Color) = (0,0,0,1)
		_SpecGlossMap("Specular", 2D) = "white" {}

		_MainTex("Albedo", 2D) = "white" {}
		
		_ToonColor("ToonColor", Color) = (0.5,0.5,0.5,1)
		_ToonTex("ToonTexture", 2D) = "white" {}
		_ToonPow("ToonPow", Range(1.0, 8.0)) = 2.0
		_ToonCen("ToonCen", Range(-1.0, 1.0)) = 0.0

		_EdgeColor("EdgeColor", Color) = (1,1,1,1)
		_EdgeThickness("EdgeColor", Float) = 0.01
		_EdgeOffsetFactor("_EdgeOffsetFactor", Float) = 1.0
		_EdgeOffsetUnits("_EdgeOffsetUnits", Float) = 1.0
		[HideInInspector] _EdgeSrcBlend ("__src", Float) = 1.0
		[HideInInspector] _EdgeDstBlend ("__dst", Float) = 0.0

		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		_MetallicGlossMap("Metallic", 2D) = "white" {}

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		_ParallaxMap ("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}
		
		_DetailMask("Detail Mask", 2D) = "white" {}

		_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
		_DetailNormalMapScale("Scale", Float) = 1.0
		_DetailNormalMap("Normal Map", 2D) = "bump" {}

		[Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0

		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
		[HideInInspector] _Cull ("__cull", Float) = 2.0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" "ForceNoShadowCasting"="True" }

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }

			Blend [_EdgeSrcBlend] [_EdgeDstBlend]
			ZWrite [_ZWrite]
			Cull Front
			Offset [_EdgeOffsetFactor],[_EdgeOffsetUnits]

			CGPROGRAM
			#pragma target 2.0
			
			#pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			#pragma vertex vertForwardBase
			#pragma fragment fragForwardBase
			#define UNITY_PASS_FORWARDBASE
			#include "UnityStandardToonEdge.cginc"

			ENDCG
		}

		// ------------------------------------------------------------------
		//  Additive forward pass (one light per pass)
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_EdgeSrcBlend] One
			Fog { Color (0,0,0,0) } // in additive pass fog should be black
			ZWrite Off
			ZTest LEqual
			Cull Front
			Offset [_EdgeOffsetFactor],[_EdgeOffsetUnits]
			
			CGPROGRAM
			#pragma target 2.0

			#pragma skip_variants SHADOWS_SOFT
			
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			
			#pragma vertex vertForwardAdd
			#pragma fragment fragForwardAdd
			#define UNITY_PASS_FORWARDADD
			#include "UnityStandardToonEdge.cginc"

			ENDCG
		}
	}

	FallBack Off
}
