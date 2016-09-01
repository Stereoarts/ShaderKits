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
	return fragForwardBaseSimpleInternal(i); // Redirect to default.
}
half4 fragToonForwardBaseSimpleInternal(VertexOutputBaseSimple i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
{
	return fragForwardBaseSimpleInternal(i); // Redirect to default.
}

VertexOutputForwardAddSimple vertToonForwardAddSimple (VertexInput v)
{
	return vertForwardAddSimple(v);
}
half4 fragToonForwardAddSimple (VertexOutputForwardAddSimple i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
{
	return fragForwardAddSimpleInternal(i); // Redirect to default.
}

half4 fragToonForwardAddSimpleInternal(VertexOutputForwardAddSimple i) : SV_Target
{
	return fragForwardAddSimpleInternal(i); // Redirect to default.
}

#endif // UNITY_STANDARD_TOON_CORE_FORWARD_SIMPLE_INCLUDED
