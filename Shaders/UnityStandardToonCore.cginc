#ifndef UNITY_STANDARD_TOON_CORE_INCLUDED
#define UNITY_STANDARD_TOON_CORE_INCLUDED

#include "UnityStandardToonConfig.cginc"
#include "UnityStandardCore.cginc"

half4 _ToonColor;
sampler2D _ToonTex;
half _ToonPow;
half _ToonCen;

#if defined(_TOON_TEX) || defined(_TOON_COLOR)
#define _TOON
#endif

//-------------------------------------------------------------------------------------

// Default BRDF to use:
#if !defined (UNITY_TOON_BRDF_PBS) // allow to explicitly override BRDF in custom shader
	// still add safe net for low shader models, otherwise we might end up with shaders failing to compile
	// the only exception is WebGL in 5.3 - it will be built with shader target 2.0 but we want it to get rid of constraints, as it is effectively desktop
	#if SHADER_TARGET < 30 && !UNITY_53_SPECIFIC_TARGET_WEBGL
		#define UNITY_TOON_BRDF_PBS BRDF3_Unity_Toon_PBS
	#elif UNITY_PBS_USE_BRDF3
		#define UNITY_TOON_BRDF_PBS BRDF3_Unity_Toon_PBS
	#elif UNITY_PBS_USE_BRDF2
		#define UNITY_TOON_BRDF_PBS BRDF2_Unity_Toon_PBS
	#elif UNITY_PBS_USE_BRDF1
		#define UNITY_TOON_BRDF_PBS BRDF1_Unity_Toon_PBS
	#elif defined(SHADER_TARGET_SURFACE_ANALYSIS)
		// we do preprocess pass during shader analysis and we dont actually care about brdf as we need only inputs/outputs
		#define UNITY_TOON_BRDF_PBS BRDF1_Unity_Toon_PBS
	#else
		#error something broke in auto-choosing BRDF
	#endif
#endif

//-------------------------------------------------------------------------------------

inline void _TOON_BRDF_NdotL(half3 normal, UnityLight light, out half ndotl, out half ndotl_uc)
{
	ndotl_uc = dot(normal, light.dir);
	ndotl = saturate(ndotl_uc);
}

inline void TOON_BRDF_NdotL(half3 normal, UnityLight light, out half ndotl, out half ndotl_uc)
{
	ndotl_uc = dot(normal, light.dir);
#if UNITY_VERSION >= 550
	ndotl = saturate(ndotl_uc);
#else
	ndotl = light.ndotl;
#endif
}

inline void TOON_BRDF_NdotL(half3 normal, UnityLight light, out half ndotl)
{
#if UNITY_VERSION >= 550
	half ndotl_uc = dot(normal, light.dir);
	ndotl = saturate(ndotl_uc);
#else
	ndotl = light.ndotl;
#endif
}

//-------------------------------------------------------------------------------------

inline half TOON_GetToolRefl(half nl)
{
	return nl * 0.5 + 0.5;
}

inline half TOON_GetToonShadow(half refl)
{
	half toonShadow = (refl - _ToonCen) * 2.0;
	return (half)saturate(pow(toonShadow, _ToonPow) - 1.0);
}

// for ForwardBase
inline half3 TOON_GetRamp(half nl, half shadowAtten)
{
	half refl = min(TOON_GetToolRefl(nl), shadowAtten);

#ifdef _TOON_TEX
	return (half3)tex2D(_ToonTex, half2(refl, refl));
#elif defined(_TOON_COLOR)
	return lerp(_ToonColor.rgb, half3(1.0, 1.0, 1.0), TOON_GetToonShadow(refl));
#else
	return half3(1.0, 1.0, 1.0);
#endif
}

// for ForwardAdd
inline half3 TOON_GetRamp_Add(half refl, half toonShadow)
{
#ifdef _TOON_TEX
	return (half3)tex2D(_ToonTex, half2(refl, refl));
#elif defined(_TOON_COLOR)
	return lerp(_ToonColor.rgb, half3(1.0, 1.0, 1.0), toonShadow);
#else
	return half3(1.0, 1.0, 1.0);
#endif
}

#define _AddLightToonMin -0.1
#define _AddLightToonCen 0.5

inline half TOON_GetForwardAddStr(half toonRefl)
{
	half toonShadow = (toonRefl - _AddLightToonCen) * 2.0;
	return (half)clamp(toonShadow * toonShadow - 1.0, _AddLightToonMin, 1.0);
}

//-------------------------------------------------------------------------------------

VertexOutputForwardBase vertToonForwardBase (VertexInput v)
{
	return vertForwardBase (v); // Redirect to default.
}

//-------------------------------------------------------------------------------------

// Main Physically Based BRDF
// Derived from Disney work and based on Torrance-Sparrow micro-facet model
//
//   BRDF = kD / pi + kS * (D * V * F) / 4
//   I = BRDF * NdotL
//
// * NDF (depending on UNITY_BRDF_GGX):
//  a) Normalized BlinnPhong
//  b) GGX
// * Smith for Visiblity term
// * Schlick approximation for Fresnel
half4 BRDF1_Unity_Toon_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity,
#if UNITY_VERSION < 550
	half oneMinusRoughness,
#else
	half smoothness,
#endif
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half shadowAtten)
{
#if UNITY_VERSION < 550
	half roughness = 1.0 - oneMinusRoughness;
	half specularPower = RoughnessToSpecPower(roughness);
#else
	half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	half specularPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
#endif
	half3 halfDir = Unity_SafeNormalize(light.dir + viewDir);

	// NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
	// In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
	// but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
	// Following define allow to control this. Set it to 0 if ALU is critical on your platform.
	// This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
	// Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0 

	half nl, nl_uc;
#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
	// The amount we shift the normal toward the view vector is defined by the dot product.
	// This correction is only applied with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
	half shiftAmount = dot(normal, viewDir);
	normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
	// A re-normalization should be apply here but as the shift is small we don't do it to save ALU.
	//normal = normalize(normal);

	// As we have modify the normal we need to recalculate the dot product nl. 
	// Note that  light.ndotl is a clamped cosine and only the ForwardSimple mode use a specific ndotL with BRDF3
	half nl = DotClamped(normal, light.dir);
	_TOON_BRDF_NdotL(normal, light, nl, nl_uc);
#else
	TOON_BRDF_NdotL(normal, light, nl, nl_uc);
#endif

	half nh = BlinnTerm(normal, halfDir);
	half nv = DotClamped(normal, viewDir);

	half lv = DotClamped(light.dir, viewDir);
	half lh = DotClamped(light.dir, halfDir);

#if UNITY_BRDF_GGX
	half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
	half D = GGXTerm(nh, roughness);
#else
	half V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
	half D = NDFBlinnPhongNormalizedTerm(nh, RoughnessToSpecPower(roughness));
#endif

	half nlPow5 = Pow5(1 - nl);
	half nvPow5 = Pow5(1 - nv);
#if UNITY_VERSION < 550
	half Fd90 = 0.5 + 2 * lh * lh * roughness;
#else
	half Fd90 = 0.5 + 2 * lh * lh * perceptualRoughness;
#endif
	half disneyDiffuse = (1 + (Fd90 - 1) * nlPow5) * (1 + (Fd90 - 1) * nvPow5);

	// HACK: theoretically we should divide by Pi diffuseTerm and not multiply specularTerm!
	// BUT 1) that will make shader look significantly darker than Legacy ones
	// and 2) on engine side "Non-important" lights have to be divided by Pi to in cases when they are injected into ambient SH
	// NOTE: multiplication by Pi is part of single constant together with 1/4 now
	half specularTerm = (V * D) * (UNITY_PI / 4); // Torrance-Sparrow model, Fresnel is applied later (for optimization reasons)
	if (IsGammaSpace())
		specularTerm = sqrt(max(1e-4h, specularTerm));
	specularTerm = max(0, specularTerm * nl);

#ifdef _TOON
	half toonNdotL = clamp(nl_uc * disneyDiffuse, -1.0, 1.0);
#ifdef UNITY_PASS_FORWARDADD
	half toonRefl = TOON_GetToolRefl(toonNdotL);
	half toonShadow = TOON_GetToonShadow(toonRefl);
	half3 diffuseTerm = TOON_GetRamp_Add(toonRefl, toonShadow);
#else // UNITY_PASS_FORWARDADD
	half3 diffuseTerm = TOON_GetRamp(toonNdotL, shadowAtten);
#endif // UNITY_PASS_FORWARDADD
#else // _TOON
	half3 diffuseTerm = disneyDiffuse * nl; // Warning: half to half3
#endif // _TOON

#if UNITY_VERSION < 550
	// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(realRoughness^2+1)
	half realRoughness = roughness*roughness;		// need to square perceptual roughness
	half surfaceReduction;
	if (IsGammaSpace()) surfaceReduction = 1.0 - 0.28*realRoughness*roughness;		// 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
	else surfaceReduction = 1.0 / (realRoughness*realRoughness + 1.0);			// fade \in [0.5;1]
#else
	// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
	half surfaceReduction;
	if (IsGammaSpace()) surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;		// 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
	else surfaceReduction = 1.0 / (roughness*roughness + 1.0);			// fade \in [0.5;1]
#endif

#if UNITY_VERSION < 550
	half grazingTerm = saturate(oneMinusRoughness + (1 - oneMinusReflectivity));
#else
	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
#endif
	half3 color = diffColor * (gi.diffuse + light.color * diffuseTerm)
		+ specularTerm * light.color * FresnelTerm(specColor, lh)
		+ surfaceReduction * gi.specular * FresnelLerp(specColor, grazingTerm, nv);

#ifdef _TOON
#ifdef UNITY_PASS_FORWARDADD
	color *= TOON_GetForwardAddStr(toonRefl);
#endif // UNITY_PASS_FORWARDADD
#endif // _TOON

#ifdef UNITY_PASS_FORWARDADD
#else
#ifdef _EMISSION
	color.rgb += diffColor * _EmissionColor.rgb; // Added: Multiply with diffColor.
#endif
#endif

	return half4(color, 1);
}

// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * BlinnPhong as NDF
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half4 BRDF2_Unity_Toon_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity,
#if UNITY_VERSION < 550
	half oneMinusRoughness,
#else
	half smoothness,
#endif
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half shadowAtten)
{
	half3 halfDir = Unity_SafeNormalize(light.dir + viewDir);

	half nl, nl_uc;
	TOON_BRDF_NdotL(normal, light, nl, nl_uc);
	half nh = BlinnTerm(normal, halfDir);
	half nv = DotClamped(normal, viewDir);
	half lh = DotClamped(light.dir, halfDir);

#if UNITY_VERSION < 550
	half roughness = 1.0 - oneMinusRoughness;
	half specularPower = RoughnessToSpecPower(roughness);
#else
	half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
	half specularPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
#endif
	// Modified with approximate Visibility function that takes roughness into account
	// Original ((n+1)*N.H^n) / (8*Pi * L.H^3) didn't take into account roughness 
	// and produced extremely bright specular at grazing angles

	// HACK: theoretically we should divide by Pi diffuseTerm and not multiply specularTerm!
	// BUT 1) that will make shader look significantly darker than Legacy ones
	// and 2) on engine side "Non-important" lights have to be divided by Pi to in cases when they are injected into ambient SH
	// NOTE: multiplication by Pi is cancelled with Pi in denominator

#if UNITY_VERSION < 550
	half invV = lh * lh * oneMinusRoughness + roughness * roughness; // approx ModifiedKelemenVisibilityTerm(lh, 1-oneMinusRoughness);
#else
	half invV = lh * lh * smoothness + perceptualRoughness * perceptualRoughness; // approx ModifiedKelemenVisibilityTerm(lh, perceptualRoughness);
#endif
	half invF = lh;
	half specular = ((specularPower + 1) * pow(nh, specularPower)) / (8 * invV * invF + 1e-4h);
	if (IsGammaSpace())
		specular = sqrt(max(1e-4h, specular));

#if UNITY_VERSION < 550
	// surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(realRoughness^2+1)
	half realRoughness = roughness*roughness;		// need to square perceptual roughness
													// 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
													// 1-x^3*(0.6-0.08*x)   approximation for 1/(x^4+1)
	half surfaceReduction = IsGammaSpace() ? 0.28 : (0.6 - 0.08*roughness);
	surfaceReduction = 1.0 - realRoughness*roughness*surfaceReduction;
#else
	// 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
	// 1-x^3*(0.6-0.08*x)   approximation for 1/(x^4+1)
	half surfaceReduction = IsGammaSpace() ? 0.28 : (0.6 - 0.08*perceptualRoughness);
	surfaceReduction = 1.0 - roughness*perceptualRoughness*surfaceReduction;
#endif

	// Prevent FP16 overflow on mobiles
#if SHADER_API_GLES || SHADER_API_GLES3
	specular = clamp(specular, 0.0, 100.0);
#endif

	half3 specLight = light.color * nl;
#ifdef _TOON
	half3 toonNdotL = nl_uc;
#ifdef UNITY_PASS_FORWARDADD
	half toonRefl = TOON_GetToolRefl(toonNdotL);
	half toonShadow = TOON_GetToonShadow(toonRefl);
	half3 ramp = TOON_GetRamp_Add(toonRefl, toonShadow);
#else // UNITY_PASS_FORWARDADD
	half3 ramp = TOON_GetRamp(toonNdotL, shadowAtten);
#endif // UNITY_PASS_FORWARDADD
	half3 diffDirect = light.color * ramp;
#else // _TOON
	half3 diffDirect = specLight;
#endif // _TOON

	half3 color = diffColor * (gi.diffuse + diffDirect)
		+ specular * specColor * specLight;

#ifdef UNITY_PASS_FORWARDADD
#else // UNITY_PASS_FORWARDADD
#if UNITY_VERSION < 550
	half grazingTerm = saturate(oneMinusRoughness + (1 - oneMinusReflectivity));
#else
	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
#endif
	color += surfaceReduction * gi.specular * FresnelLerpFast(specColor, grazingTerm, nv);
#endif // UNITY_PASS_FORWARDADD

#ifdef _TOON
#ifdef UNITY_PASS_FORWARDADD
	color *= TOON_GetForwardAddStr(toonRefl);
#endif // UNITY_PASS_FORWARDADD
#endif // _TOON

#ifdef UNITY_PASS_FORWARDADD
#else
#ifdef _EMISSION
	color.rgb += diffColor * _EmissionColor.rgb; // Added: Multiply with diffColor.
#endif
#endif

	return half4(color, 1);
}

half3 TOON_BRDF3_Specular(half3 specColor, half rlPow4, half roughness)
{
	half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
						   // Lookup texture to save instructions
	half specular = tex2D(unity_NHxRoughness, half2(rlPow4, roughness)).UNITY_ATTEN_CHANNEL * LUT_RANGE;
	return specular * specColor;
}

// Old school, not microfacet based Modified Normalized Blinn-Phong BRDF
// Implementation uses Lookup texture for performance
//
// * Normalized BlinnPhong in RDF form
// * Implicit Visibility term
// * No Fresnel term
//
// TODO: specular is too weak in Linear rendering mode
half4 BRDF3_Unity_Toon_PBS(half3 diffColor, half3 specColor, half oneMinusReflectivity,
#if UNITY_VERSION < 550
	half oneMinusRoughness,
#else
	half smoothness,
#endif
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi, half shadowAtten)
{
	half3 reflDir = reflect(viewDir, normal);

	half nl, nl_uc;
	TOON_BRDF_NdotL(normal, light, nl, nl_uc);
	half nv = DotClamped(normal, viewDir);

	// Vectorize Pow4 to save instructions
	half2 rlPow4AndFresnelTerm = Pow4(half2(dot(reflDir, light.dir), 1 - nv));  // use R.L instead of N.H to save couple of instructions
	half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
	half fresnelTerm = rlPow4AndFresnelTerm.y;

	half3 diffDirect = diffColor;
#if UNITY_VERSION < 550
	half3 specDirect = TOON_BRDF3_Specular(specColor, rlPow4, 1.0 - oneMinusRoughness);
#else
	half3 specDirect = TOON_BRDF3_Specular(specColor, rlPow4, SmoothnessToPerceptualRoughness(smoothness));
#endif

#ifdef _TOON
	half3 toonNdotL = nl_uc;
#ifdef UNITY_PASS_FORWARDADD
	half toonRefl = TOON_GetToolRefl(toonNdotL);
	half toonShadow = TOON_GetToonShadow(toonRefl);
	half3 ramp = TOON_GetRamp_Add(toonRefl, toonShadow);
#else // UNITY_PASS_FORWARDADD
	half3 ramp = TOON_GetRamp(toonNdotL, shadowAtten);
#endif // UNITY_PASS_FORWARDADD
	half3 color = (diffDirect * ramp + specDirect * nl) * light.color;
#else // _TOON
	half3 color = (diffDirect + specDirect) * light.color * nl;
#endif // _TOON

#ifdef UNITY_PASS_FORWARDADD
#else // UNITY_PASS_FORWARDADD
#if UNITY_VERSION < 550
	half grazingTerm = saturate(oneMinusRoughness + (1.0 - oneMinusReflectivity));
#else
	half grazingTerm = saturate(smoothness + (1.0 - oneMinusReflectivity));
#endif
	color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
#endif // UNITY_PASS_FORWARDADD

#ifdef _TOON
#ifdef UNITY_PASS_FORWARDADD
	color *= TOON_GetForwardAddStr(toonRefl);
#endif // UNITY_PASS_FORWARDADD
#endif // _TOON

#ifdef UNITY_PASS_FORWARDADD
#else
#ifdef _EMISSION
	color.rgb += diffColor * _EmissionColor.rgb; // Added: Multiply with diffColor.
#endif
#endif

	return half4(color, 1);
}

half4 fragToonForwardBaseInternal(VertexOutputForwardBase i)
{
	FRAGMENT_SETUP(s) // clip() into FragmentSetup()

#if UNITY_OPTIMIZE_TEXCUBELOD
	s.reflUVW = i.reflUVW;
#endif

#if UNITY_VERSION < 550
	UnityLight mainLight = MainLight(s.normalWorld);
#else
	UnityLight mainLight = MainLight();
#endif
	half shadowAtten = SHADOW_ATTENUATION(i);

	half occlusion = Occlusion(i.tex.xy);
	UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, shadowAtten, mainLight);

	half4 c = UNITY_TOON_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity,
#if UNITY_VERSION < 550
		s.oneMinusRoughness,
#else
		s.smoothness,
#endif
		s.normalWorld, -s.eyeVec,
#ifdef _TOON
		mainLight,
#else
		gi.light,
#endif
		gi.indirect, shadowAtten);
	c.rgb += UNITY_BRDF_GI(s.diffColor, s.specColor, s.oneMinusReflectivity,
#if UNITY_VERSION < 550
		s.oneMinusRoughness,
#else
		s.smoothness,
#endif
		s.normalWorld, -s.eyeVec, occlusion, gi);

	UNITY_APPLY_FOG(i.fogCoord, c.rgb);
	return OutputForward(c, s.alpha);
}

half4 fragToonForwardBase(VertexOutputForwardBase i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
{
	return fragToonForwardBaseInternal(i);
}

VertexOutputForwardAdd vertToonForwardAdd (VertexInput v)
{
	return vertForwardAdd (v); // Redirect to default.
}

half4 fragToonForwardAddInternal (VertexOutputForwardAdd i)
{
	FRAGMENT_SETUP_FWDADD(s) // clip() into FragmentSetup()

	UnityLight light = AdditiveLight (
#if UNITY_VERSION < 550
		s.normalWorld,
#endif
		IN_LIGHTDIR_FWDADD(i), LIGHT_ATTENUATION(i));

	UnityIndirect noIndirect = ZeroIndirect ();

	half4 c = UNITY_TOON_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity,
#if UNITY_VERSION < 550
		s.oneMinusRoughness,
#else
		s.smoothness,
#endif
		s.normalWorld, -s.eyeVec, light, noIndirect, 0.0);

	UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
	return OutputForward (c, s.alpha);
}

half4 fragToonForwardAdd(VertexOutputForwardAdd i) : SV_Target		// backward compatibility (this used to be the fragment entry function)
{
	return fragToonForwardAddInternal(i);
}

// ------------------------------------------------------------------
//  Deferred pass

VertexOutputDeferred vertToonDeferred (VertexInput v)
{
	return vertDeferred(v); // Redirect to default.
}

void fragToonDeferred (
	VertexOutputDeferred i,
	out half4 outDiffuse : SV_Target0,			// RT0: diffuse color (rgb), occlusion (a)
	out half4 outSpecSmoothness : SV_Target1,	// RT1: spec color (rgb), smoothness (a)
	out half4 outNormal : SV_Target2,			// RT2: normal (rgb), --unused, very low precision-- (a) 
	out half4 outEmission : SV_Target3			// RT3: emission (rgb), --unused-- (a)
)
{
	fragDeferred(i, outDiffuse, outSpecSmoothness, outNormal, outEmission); // Redirect to default.
}

#endif // UNITY_STANDARD_TOON_CORE_INCLUDED
