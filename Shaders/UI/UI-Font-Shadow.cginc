#include "UnityCG.cginc"
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct v2f members shadowLength)
#pragma exclude_renderers d3d11 xbox360
#include "UnityUI.cginc"

struct appdata_t
{
	float4 vertex   : POSITION;
	float4 color    : COLOR;
	float2 texcoord : TEXCOORD0;
	uint vertexID   : SV_VertexID;
};

struct v2f
{
	float4 vertex   : SV_POSITION;
	fixed4 color    : COLOR;
	half2 texcoord  : TEXCOORD0;
	float4 worldPosition : TEXCOORD1;
	#ifdef SHADERKITS_UI_OUTLINE
	float4 uvgrab : TEXCOORD2;
	#endif
};

fixed4 _Color;
fixed4 _TextureSampleAdd;
float4 _ClipRect;
#if defined(SHADERKITS_UI_OUTLINE) || defined(SHADERKITS_UI_OUTLINE_ALPHACLEAR)
int _ShadowLength;
#endif
#if defined(SHADERKITS_UI_OUTLINE)
float4 _ShadowColor;
#endif

v2f vert(appdata_t IN)
{
	#if defined(SHADERKITS_UI_OUTLINE) || defined(SHADERKITS_UI_OUTLINE_ALPHACLEAR)
	uint vertexID = IN.vertexID % 4;
	float2 shadowOffset;
	shadowOffset.x = 1.0 - abs(1.5 - vertexID);
	shadowOffset.y = 0.5 - vertexID / 2;
	shadowOffset = shadowOffset * _ShadowLength;
	#endif // defined(SHADERKITS_UI_OUTLINE) || defined(SHADERKITS_UI_OUTLINE_ALPHACLEAR)

	v2f OUT;
	OUT.worldPosition = IN.vertex;
	OUT.vertex = mul(UNITY_MATRIX_MVP, OUT.worldPosition);

	OUT.texcoord = IN.texcoord;
	#ifdef UNITY_HALF_TEXEL_OFFSET
	OUT.vertex.xy += (_ScreenParams.zw-1.0)*float2(-1,1);
	#endif
	
	#ifdef SHADERKITS_UI_OUTLINE
	OUT.vertex.xy += shadowOffset * 4.0 * (_ScreenParams.zw - 1.0) * OUT.vertex.w;
	#endif // SHADERKITS_UI_OUTLINE
	#ifdef SHADERKITS_UI_OUTLINE_ALPHACLEAR
	OUT.vertex.xy += shadowOffset * 8.2 * (_ScreenParams.zw - 1.0) * OUT.vertex.w;
	#endif // SHADERKITS_UI_OUTLINE_ALPHACLEAR
	#ifdef SHADERKITS_UI_OUTLINE
	OUT.uvgrab = ComputeGrabScreenPos(OUT.vertex);
	#endif

	OUT.color = IN.color * _Color;
	return OUT;
}

sampler2D _MainTex;
#ifdef SHADERKITS_UI_OUTLINE
sampler2D _GrabTexture;
float4 _GrabTexture_TexelSize;
#endif

#ifdef SHADERKITS_UI_OUTLINE
inline float _GetShadowAlpha(v2f IN)
{
	int shadowLength = max(_ShadowLength, 1);

	float shadowAlpha = 0;

	float lengthRange = _ShadowLength;
	float lengthRangeInv = 1.0 / lengthRange;

	float2 pixelToUV = _GrabTexture_TexelSize.xy * IN.uvgrab.w;

	for (int y = -shadowLength; y <= shadowLength; ++y)
	{
		for (int x = -shadowLength; x <= shadowLength; ++x)
		{
			float4 uvgrab = IN.uvgrab;
			float2 pos = float2(x, y);
			uvgrab.xy += pos * pixelToUV;
			float alpha = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(uvgrab)).a;
			alpha *= (lengthRange - length(pos)) * lengthRangeInv;
			alpha = 1.0 - alpha;
			alpha *= alpha;
			alpha = 1.0 - alpha;
			shadowAlpha = max(shadowAlpha, alpha);
		}
	}

	return shadowAlpha;
}
#endif // SHADERKITS_UI_OUTLINE

fixed4 frag(v2f IN) : SV_Target
{
#ifdef SHADERKITS_UI_OUTLINE_ALPHACLEAR
	return fixed4(0, 0, 0, 0);
#else // SHADERKITS_UI_OUTLINE_ALPHACLEAR

#ifdef SHADERKITS_UI_OUTLINE
	half4 color;
	color.rgb = _ShadowColor.rgb;
	color.a = _GetShadowAlpha(IN) * _ShadowColor.a;

	color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);

#if defined(UNITY_UI_ALPHACLIP)
	clip(color.a - 0.001);
#endif

	half4 dstColor = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(IN.uvgrab));
	color.rgb = lerp(dstColor.rgb, color.rgb, color.a);
	return color;
#else
	half4 color = (tex2D(_MainTex, IN.texcoord) + _TextureSampleAdd) * IN.color;
	color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);

#if defined(UNITY_UI_ALPHACLIP)
	clip(color.a - 0.001);
#endif

	return color;
#endif

#endif // SHADERKITS_UI_OUTLINE_ALPHACLEAR
}
