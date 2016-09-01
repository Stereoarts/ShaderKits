// UNITY_SHADER_NO_UPGRADE

#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#if UNITY_VERSION >= 540
#define _UNITY_OBJECT_TO_WORLD	unity_ObjectToWorld
#else
#define _UNITY_OBJECT_TO_WORLD	_Object2World
#endif

half4 _EdgeColor;
half _EdgeThickness;

struct VertexOutputForwardBase
{
	float4 pos : SV_POSITION;
	half3 vlight : TEXCOORD0;
	LIGHTING_COORDS(1,2)
};

VertexOutputForwardBase vertForwardBase (appdata_full v)
{
	VertexOutputForwardBase o;
	v.vertex.xyz += v.normal.xyz * _EdgeThickness;
	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	float3 worldN = mul((float3x3)_UNITY_OBJECT_TO_WORLD, SCALED_NORMAL);
	o.vlight = ShadeSH9(float4(worldN, 1.0));
	TRANSFER_VERTEX_TO_FRAGMENT(o);
	return o;
}

#define _EdgeLightRate		0.75

half4 fragForwardBase (VertexOutputForwardBase i) : SV_Target
{
	half3 diff = _LightColor0.rgb * LIGHT_ATTENUATION(i) * _EdgeLightRate;
	diff += i.vlight;

	half4 edgeColor = _EdgeColor;
	edgeColor.rgb *= diff;
	return edgeColor;
}

//----------------------------------------------------------------------------------------------------

struct VertexOutputForwardAdd
{
	float4 pos : SV_POSITION;
	LIGHTING_COORDS(0,1)
};

VertexOutputForwardAdd vertForwardAdd (appdata_full v)
{
	VertexOutputForwardAdd o;
	v.vertex.xyz += v.normal.xyz * _EdgeThickness;
	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	TRANSFER_VERTEX_TO_FRAGMENT(o);
	return o;
}

float4 fragForwardAdd (VertexOutputForwardAdd i) : SV_Target
{
	half3 diff = _LightColor0.rgb * LIGHT_ATTENUATION(i) * _EdgeLightRate;

	half4 edgeColor = _EdgeColor;
	edgeColor.rgb *= diff;
	edgeColor.rgb *= edgeColor.a; // Premulti-Alpha
	return half4(edgeColor.rgb, 0.0);
}
