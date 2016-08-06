#ifndef UNITY_STANDARD_TOON_CONFIG_INCLUDED
#define UNITY_STANDARD_TOON_CONFIG_INCLUDED

#ifdef _BRDF_SPECULAR
	#define UNITY_SETUP_BRDF_INPUT SpecularSetup
#else
	#define UNITY_SETUP_BRDF_INPUT MetallicSetup
#endif

#endif
