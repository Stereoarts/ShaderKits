Shader "ShaderKits/UI/Font Shadow"
{
	Properties
	{
		[PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
		_Color ("Tint", Color) = (1,1,1,1)

		_StencilComp ("Stencil Comparison", Float) = 8
		_Stencil ("Stencil ID", Float) = 0
		_StencilOp ("Stencil Operation", Float) = 0
		_StencilWriteMask ("Stencil Write Mask", Float) = 255
		_StencilReadMask ("Stencil Read Mask", Float) = 255

		_ColorMask ("Color Mask", Float) = 15

		_ShadowColor("Shadow Color", Color) = (0,0,0,1)
		_ShadowLength("Shadow Length", Int) = 8

		[Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
	}

	SubShader
	{
		Tags
		{ 
			"Queue"="Transparent" 
			"IgnoreProjector"="True" 
			"RenderType"="Transparent" 
			"PreviewType"="Plane"
			"CanUseSpriteAtlas"="True"
		}
		
		Stencil
		{
			Ref [_Stencil]
			Comp [_StencilComp]
			Pass [_StencilOp] 
			ReadMask [_StencilReadMask]
			WriteMask [_StencilWriteMask]
		}

		Cull Off
		Lighting Off
		ZWrite Off
		ZTest [unity_GUIZTestMode]
		Blend SrcAlpha OneMinusSrcAlpha
		ColorMask [_ColorMask]
			
		Pass
		{
			ColorMask A
			Blend Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target es3.0 // Unity 5.3, SV_VertexID

			#define SHADERKITS_UI_OUTLINE_ALPHACLEAR
			#include "UI-Font-Shadow.cginc"
			ENDCG
		}

		Pass
		{
			ColorMask A
			Blend Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target es3.0 // Unity 5.3, SV_VertexID

			#pragma multi_compile __ UNITY_UI_ALPHACLIP
			#define SHADERKITS_UI_OUTLINE_ALPHADRAW
			#include "UI-Font-Shadow.cginc"
			ENDCG
		}

		GrabPass{}

		Pass
		{
			ColorMask RGB
			Blend Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target es3.0 // Unity 5.3, SV_VertexID

			#pragma multi_compile __ UNITY_UI_ALPHACLIP
			#define SHADERKITS_UI_OUTLINE
			#include "UI-Font-Shadow.cginc"
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile __ UNITY_UI_ALPHACLIP
			#define SHADERKITS_UI_MAIN
			#include "UI-Font-Shadow.cginc"
			ENDCG
		}

	}
}

