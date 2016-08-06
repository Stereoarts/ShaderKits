#ifndef UNITY_STANDARD_TOON_CORE_FORWARD_INCLUDED
#define UNITY_STANDARD_TOON_CORE_FORWARD_INCLUDED

#if defined(UNITY_NO_FULL_STANDARD_SHADER)
#	define UNITY_STANDARD_SIMPLE 1
#endif

#include "UnityStandardToonConfig.cginc"
#include "UnityStandardConfig.cginc"

#if UNITY_STANDARD_SIMPLE
	#include "UnityStandardToonCoreForwardSimple.cginc"
	VertexOutputBaseSimple vertBase (VertexInput v) { return vertToonForwardBaseSimple(v); }
	VertexOutputForwardAddSimple vertAdd (VertexInput v) { return vertToonForwardAddSimple(v); }
	half4 fragBase (VertexOutputBaseSimple i) : SV_Target { return fragToonForwardBaseSimpleInternal(i); }
	half4 fragAdd (VertexOutputForwardAddSimple i) : SV_Target { return fragToonForwardAddSimpleInternal(i); }
#else
	#include "UnityStandardToonCore.cginc"
	VertexOutputForwardBase vertBase (VertexInput v) { return vertToonForwardBase(v); }
	VertexOutputForwardAdd vertAdd (VertexInput v) { return vertToonForwardAdd(v); }
	half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragToonForwardBaseInternal(i); }
	half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragToonForwardAddInternal(i); }
#endif

#endif // UNITY_STANDARD_TOON_CORE_FORWARD_INCLUDED
