#ifndef UNITY_STANDARD_TOON_CORE_FORWARD_SIMPLE_INCLUDED
#define UNITY_STANDARD_TOON_CORE_FORWARD_SIMPLE_INCLUDED

#include "UnityStandardToonCore.cginc"
#include "UnityStandardCoreForwardSimple.cginc"

VertexOutputBaseSimple vertToonForwardBaseSimple (VertexInput v)
{
	return vertForwardBaseSimple(v);
}
half4 fragToonForwardBaseSimple (VertexOutputBaseSimple i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
{
	return fragForwardBaseSimpleInternal(i);
}

VertexOutputForwardAddSimple vertToonForwardAddSimple (VertexInput v)
{
	return vertForwardAddSimple(v);
}
half4 fragToonForwardAddSimple (VertexOutputForwardAddSimple i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
{
	return fragForwardAddSimpleInternal(i);
}

#endif // UNITY_STANDARD_TOON_CORE_FORWARD_SIMPLE_INCLUDED
