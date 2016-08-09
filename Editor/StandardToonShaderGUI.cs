using System;
using UnityEditor;
using UnityEngine;

namespace ShaderKits
{

class StandardToonShaderGUI : ShaderGUI
{
	private enum WorkflowMode
	{
		Specular,
		Metallic,
		Dielectric
	}

	public enum BlendMode
	{
		Opaque,
		Cutout,
		Fade,		// Old school alpha-blending mode, fresnel does not affect amount of transparency
		Transparent // Physically plausible transparency mode, implemented as alpha pre-multiply
	}

	public enum ToonMode
	{
		None,
		Color,
		Texture,
	}

	private static class Styles
	{
		public static GUIStyle optionsButton = "PaneOptions";
		public static GUIContent uvSetLabel = new GUIContent("UV Set");
		public static GUIContent[] uvSetOptions = new GUIContent[] { new GUIContent("UV channel 0"), new GUIContent("UV channel 1") };

		public static string emptyTootip = "";
		public static GUIContent albedoText = new GUIContent("Albedo", "Albedo (RGB) and Transparency (A)");
		public static GUIContent alphaCutoffText = new GUIContent("Alpha Cutoff", "Threshold for alpha cutoff");
		public static GUIContent specularMapText = new GUIContent("Specular", "Specular (RGB) and Smoothness (A)");
		public static GUIContent metallicMapText = new GUIContent("Metallic", "Metallic (R) and Smoothness (A)");
		public static GUIContent smoothnessText = new GUIContent("Smoothness", "");
		public static GUIContent normalMapText = new GUIContent("Normal Map", "Normal Map");
		public static GUIContent heightMapText = new GUIContent("Height Map", "Height Map (G)");
		public static GUIContent occlusionText = new GUIContent("Occlusion", "Occlusion (G)");
		public static GUIContent emissionText = new GUIContent("Emission", "Emission (RGB)");
		public static GUIContent detailMaskText = new GUIContent("Detail Mask", "Mask for Secondary Maps (A)");
		public static GUIContent detailAlbedoText = new GUIContent("Detail Albedo x2", "Albedo (RGB) multiplied by 2");
		public static GUIContent detailNormalMapText = new GUIContent("Normal Map", "Normal Map");

		public static string whiteSpaceString = " ";
		public static string primaryMapsText = "Main Maps";
		public static string secondaryMapsText = "Secondary Maps";
		public static string renderingMode = "Rendering Mode";
		public static GUIContent emissiveWarning = new GUIContent ("Emissive value is animated but the material has not been configured to support emissive. Please make sure the material itself has some amount of emissive.");
		public static GUIContent emissiveColorWarning = new GUIContent ("Ensure emissive color is non-black for emission to have effect.");
		public static readonly string[] blendNames = Enum.GetNames (typeof (BlendMode));
	}

	MaterialProperty blendMode = null;
	MaterialProperty albedoMap = null;
	MaterialProperty albedoColor = null;
	MaterialProperty alphaCutoff = null;
	MaterialProperty specularMap = null;
	MaterialProperty specularColor = null;
	MaterialProperty metallicMap = null;
	MaterialProperty metallic = null;
	MaterialProperty smoothness = null;
	MaterialProperty bumpScale = null;
	MaterialProperty bumpMap = null;
	MaterialProperty occlusionStrength = null;
	MaterialProperty occlusionMap = null;
	MaterialProperty heigtMapScale = null;
	MaterialProperty heightMap = null;
	MaterialProperty emissionColorForRendering = null;
	MaterialProperty emissionMap = null;
	MaterialProperty detailMask = null;
	MaterialProperty detailAlbedoMap = null;
	MaterialProperty detailNormalMapScale = null;
	MaterialProperty detailNormalMap = null;
	MaterialProperty uvSetSecondary = null;
	MaterialProperty toonMode = null;

	MaterialEditor m_MaterialEditor;
	WorkflowMode m_WorkflowMode = WorkflowMode.Specular;
	ColorPickerHDRConfig m_ColorPickerHDRConfig = new ColorPickerHDRConfig(0f, 99f, 1/99f, 3f);

	bool m_FirstTimeApply = true;

	public void FindProperties (MaterialProperty[] props)
	{
		blendMode = FindProperty ("_Mode", props);
		albedoMap = FindProperty ("_MainTex", props);
		albedoColor = FindProperty ("_Color", props);
		alphaCutoff = FindProperty ("_Cutoff", props);
		specularMap = FindProperty ("_SpecGlossMap", props, false);
		specularColor = FindProperty ("_SpecColor", props, false);
		metallicMap = FindProperty ("_MetallicGlossMap", props, false);
		metallic = FindProperty ("_Metallic", props, false);
		if (specularMap != null && specularColor != null)
			m_WorkflowMode = WorkflowMode.Specular;
		else if (metallicMap != null && metallic != null)
			m_WorkflowMode = WorkflowMode.Metallic;
		else
			m_WorkflowMode = WorkflowMode.Dielectric;
		smoothness = FindProperty ("_Glossiness", props);
		bumpScale = FindProperty ("_BumpScale", props);
		bumpMap = FindProperty ("_BumpMap", props);
		heigtMapScale = FindProperty ("_Parallax", props);
		heightMap = FindProperty("_ParallaxMap", props);
		occlusionStrength = FindProperty ("_OcclusionStrength", props);
		occlusionMap = FindProperty ("_OcclusionMap", props);
		emissionColorForRendering = FindProperty ("_EmissionColor", props);
		emissionMap = FindProperty ("_EmissionMap", props);
		detailMask = FindProperty ("_DetailMask", props);
		detailAlbedoMap = FindProperty ("_DetailAlbedoMap", props);
		detailNormalMapScale = FindProperty ("_DetailNormalMapScale", props);
		detailNormalMap = FindProperty ("_DetailNormalMap", props);
		uvSetSecondary = FindProperty ("_UVSec", props);
	}

	public override void OnGUI (MaterialEditor materialEditor, MaterialProperty[] props)
	{
		FindProperties (props); // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly
		m_MaterialEditor = materialEditor;
		Material material = materialEditor.target as Material;

		// Make sure that needed keywords are set up if we're switching some existing
		// material to a standard shader.
		// Do this before any GUI code has been issued to prevent layout issues in subsequent GUILayout statements (case 780071)
		if (m_FirstTimeApply)
		{
			SetMaterialKeywords (material, m_WorkflowMode);
			m_FirstTimeApply = false;
		}

		ShaderPropertiesGUI (material);
	}

	public void ShaderPropertiesGUI (Material material)
	{
		// Use default labelWidth
		EditorGUIUtility.labelWidth = 0f;

		DrawBRDF(material);

		EditorGUILayout.Space();

		// Detect any changes to the material
		EditorGUI.BeginChangeCheck();
		{
			BlendModePopup();

			// Primary properties
			GUILayout.Label (Styles.primaryMapsText, EditorStyles.boldLabel);
			DoAlbedoArea(material);
			DoSpecularMetallicArea();
			m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, bumpMap, bumpMap.textureValue != null ? bumpScale : null);
			m_MaterialEditor.TexturePropertySingleLine(Styles.heightMapText, heightMap, heightMap.textureValue != null ? heigtMapScale : null);
			m_MaterialEditor.TexturePropertySingleLine(Styles.occlusionText, occlusionMap, occlusionMap.textureValue != null ? occlusionStrength : null);
			DoEmissionArea(material);
			m_MaterialEditor.TexturePropertySingleLine(Styles.detailMaskText, detailMask);
			EditorGUI.BeginChangeCheck();
			m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
			if (EditorGUI.EndChangeCheck())
				emissionMap.textureScaleAndOffset = albedoMap.textureScaleAndOffset; // Apply the main texture scale and offset to the emission texture as well, for Enlighten's sake

			EditorGUILayout.Space();

			// Secondary properties
			GUILayout.Label(Styles.secondaryMapsText, EditorStyles.boldLabel);
			m_MaterialEditor.TexturePropertySingleLine(Styles.detailAlbedoText, detailAlbedoMap);
			m_MaterialEditor.TexturePropertySingleLine(Styles.detailNormalMapText, detailNormalMap, detailNormalMapScale);
			m_MaterialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
			m_MaterialEditor.ShaderProperty(uvSetSecondary, Styles.uvSetLabel.text);

			EditorGUILayout.Space();

			DrawToon(material);
			DrawEdge(material);
			DrawRenderState(material);
		}
		if (EditorGUI.EndChangeCheck())
		{
			foreach (var obj in blendMode.targets)
				MaterialChanged((Material)obj, m_WorkflowMode);
		}
	}

	bool _brdf_specular;
	ToonMode _toonMode;

	internal void DrawBRDF(Material material)
	{
		GUILayout.Label("BRDF", EditorStyles.boldLabel);

		_brdf_specular = material.IsKeywordEnabled("_BRDF_SPECULAR");
		EditorGUI.BeginChangeCheck();
		_brdf_specular = EditorGUILayout.Toggle("Specular", _brdf_specular);
		if( EditorGUI.EndChangeCheck() ) {
			if( _brdf_specular ) {
				material.EnableKeyword( "_BRDF_SPECULAR" );
			} else {
				material.DisableKeyword( "_BRDF_SPECULAR" );
			}
			EditorUtility.SetDirty( material );
		}

		DetermineWorkflow(material);
	}

	internal void DrawToon(Material material)
	{
		EditorGUILayout.Space();

		GUILayout.Label("Toon", EditorStyles.boldLabel);

		if( material.IsKeywordEnabled("_TOON_COLOR") ) {
			_toonMode = ToonMode.Color;
		} else if( material.IsKeywordEnabled("_TOON_TEX") ) {
			_toonMode = ToonMode.Texture;
		} else {
			_toonMode = ToonMode.None;
		}

		EditorGUI.BeginChangeCheck();
		_toonMode = (ToonMode)EditorGUILayout.EnumPopup( "Toon", _toonMode );
		if( EditorGUI.EndChangeCheck() ) {
			material.DisableKeyword( "_TOON_COLOR" );
			material.DisableKeyword( "_TOON_TEX" );
			switch( _toonMode ) {
			case ToonMode.Color:
				material.EnableKeyword( "_TOON_COLOR" );
				break;
			case ToonMode.Texture:
				material.EnableKeyword( "_TOON_TEX" );
				break;
			}
			EditorUtility.SetDirty( material );
		}

		if( _toonMode == ToonMode.None ) {
			return;
		}								  

		Color toonColor = material.GetColor("_ToonColor");
		Texture2D toonTexture = material.GetTexture("_ToonTex") as Texture2D;
		float toonCen = material.GetFloat("_ToonCen");
		float toonPow = material.GetFloat("_ToonPow");

		EditorGUI.BeginChangeCheck();
		switch( _toonMode ) {
		case ToonMode.Color:
			toonColor = EditorGUILayout.ColorField( "Color", toonColor );
			toonCen = EditorGUILayout.Slider( "Center", toonCen, -0.5f, 0.5f );
			toonPow = EditorGUILayout.FloatField( "Pow", toonPow );
			break;
		case ToonMode.Texture:
			toonTexture = (Texture2D)EditorGUILayout.ObjectField( "Texture", toonTexture, typeof(Texture2D), false );
			break;
		}
		if( EditorGUI.EndChangeCheck() ) {
			material.SetColor( "_ToonColor", toonColor );
			material.SetTexture( "_ToonTex", toonTexture );
			material.SetFloat( "_ToonCen", toonCen );
			material.SetFloat( "_ToonPow", toonPow );
			EditorUtility.SetDirty( material );
		}
	}

	internal void DrawEdge(Material material)
	{
		EditorGUILayout.Space();

		GUILayout.Label("Edge", EditorStyles.boldLabel);

		string shaderName = material.shader.name;
		bool edgeEnabled = shaderName.Contains(" Edge");
		EditorGUI.BeginChangeCheck();
		edgeEnabled = EditorGUILayout.Toggle( " Edge", edgeEnabled );
		if( EditorGUI.EndChangeCheck() ) {
			if( edgeEnabled ) {
				shaderName = shaderName + " Edge";
			} else {
				shaderName = shaderName.Substring( 0, shaderName.IndexOf(" Edge") );
			}
			var shader = Shader.Find( shaderName );
			if( shader != null ) {
				material.shader = shader;
				EditorUtility.SetDirty( material );
			}
		}

		Color edgeColor = material.GetColor("_EdgeColor");
		float edgeThickness = material.GetFloat("_EdgeThickness");
		float edgeOffsetFactor = material.GetFloat("_EdgeOffsetFactor");
		float edgeOffsetUnits = material.GetFloat("_EdgeOffsetUnits");
		Vector2 edgeOffset = new Vector2( edgeOffsetFactor, edgeOffsetUnits );

		EditorGUI.BeginChangeCheck();
		GUI.enabled = edgeEnabled;
		edgeColor = EditorGUILayout.ColorField( " Color", edgeColor );
		edgeThickness = EditorGUILayout.FloatField( " Thickness", edgeThickness );
		edgeOffset = EditorGUILayout.Vector2Field( " Offset", edgeOffset );
		GUI.enabled = true;
		if( EditorGUI.EndChangeCheck() ) {
			material.SetColor( "_EdgeColor", edgeColor );
			material.SetFloat( "_EdgeThickness", edgeThickness );
			material.SetFloat( "_EdgeOffsetFactor", edgeOffset.x );
			material.SetFloat( "_EdgeOffsetUnits", edgeOffset.y );
			if( edgeColor.a >= 1.0f - float.Epsilon ) {
				material.SetInt("_EdgeSrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
				material.SetInt("_EdgeDstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
			} else {
				material.SetInt("_EdgeSrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
				material.SetInt("_EdgeDstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
			}

			EditorUtility.SetDirty( material );
		}
	}

	static string _Insert( string str, string posStr, string insertStr )
	{
		int idx = str.IndexOf( posStr );
		if(idx >= 0) {
			return str.Insert( idx, insertStr );
		} else {
			return str + insertStr;
		}
	}

	static string _InsertBack( string str, string posStr, string insertStr )
	{
		int idx = str.IndexOf( posStr );
		if(idx >= 0) {
			return str.Insert( idx + posStr.Length, insertStr );
		} else {
			return str + insertStr;
		}
	}

	static string _Remove( string str, string removeStr )
	{
		int idx = str.IndexOf( removeStr );
		if(idx >= 0) {
			return str.Substring( 0, idx ) + str.Substring( idx + removeStr.Length );
		} else {
			return str;
		}
	}

	internal void DrawRenderState(Material material)
	{
		EditorGUILayout.Space();
		
		GUILayout.Label("Render State", EditorStyles.boldLabel);
		
		var cull = (UnityEngine.Rendering.CullMode)material.GetInt( "_Cull" );
		EditorGUI.BeginChangeCheck();
		cull = (UnityEngine.Rendering.CullMode)EditorGUILayout.EnumPopup( " Culling", cull );
		if( EditorGUI.EndChangeCheck() ) {
			material.SetInt( "_Cull", (int)cull );
			EditorUtility.SetDirty( material );
		}

		string shaderName = material.shader.name;
		bool isNoShadowCasting = shaderName.Contains(" NoShadowCasting");
		EditorGUI.BeginChangeCheck();
		isNoShadowCasting = EditorGUILayout.Toggle( " No Shadow Casting", isNoShadowCasting );
		if( EditorGUI.EndChangeCheck() ) {
			if( isNoShadowCasting ) {
				shaderName = _InsertBack( shaderName, "Standard Toon", " NoShadowCasting" );
			} else {
				shaderName = _Remove( shaderName, " NoShadowCasting" );
			}
			var shader = Shader.Find(shaderName);
			if(shader != null) {
				material.shader = shader;
				EditorUtility.SetDirty( material );
			}
		}

		bool isDoubleSided = shaderName.Contains( " DoubleSided" );
		EditorGUI.BeginChangeCheck();
		isDoubleSided = EditorGUILayout.Toggle( " Double Sided", isDoubleSided );
		if( EditorGUI.EndChangeCheck() ) {
			if( isDoubleSided ) {
				shaderName = _Insert( shaderName, " Edge", " DoubleSided" );
			} else {
				shaderName = _Remove( shaderName, " DoubleSided" );
			}
			var shader = Shader.Find(shaderName);
			if(shader != null) {
				material.shader = shader;
				if( isDoubleSided ) {
					material.SetInt( "_Cull", (int)UnityEngine.Rendering.CullMode.Off );
				} else {
					material.SetInt( "_Cull", (int)UnityEngine.Rendering.CullMode.Back );
				}
				EditorUtility.SetDirty( material );
			}
		}

		int renderQueue = material.renderQueue;
		EditorGUI.BeginChangeCheck();
		renderQueue = EditorGUILayout.IntField( " Render Queue", renderQueue );
		if( EditorGUI.EndChangeCheck() ) {
			material.renderQueue = renderQueue;
			EditorUtility.SetDirty( material );
		}
	}

	internal void DetermineWorkflow(MaterialProperty[] props)
	{
		if (FindProperty("_SpecGlossMap", props, false) != null && FindProperty("_SpecColor", props, false) != null)
			m_WorkflowMode = WorkflowMode.Specular;
		else if (FindProperty("_MetallicGlossMap", props, false) != null && FindProperty("_Metallic", props, false) != null)
			m_WorkflowMode = WorkflowMode.Metallic;
		else
			m_WorkflowMode = WorkflowMode.Dielectric;
	}

	internal void DetermineWorkflow(Material material)
	{
		m_WorkflowMode = material.IsKeywordEnabled("_BRDF_SPECULAR") ? WorkflowMode.Specular : WorkflowMode.Metallic;
	}

	public override void AssignNewShaderToMaterial (Material material, Shader oldShader, Shader newShader)
	{
        // _Emission property is lost after assigning Standard shader to the material
        // thus transfer it before assigning the new shader
        if (material.HasProperty("_Emission"))
        {
            material.SetColor("_EmissionColor", material.GetColor("_Emission"));
        }

		base.AssignNewShaderToMaterial(material, oldShader, newShader);

		if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
			return;

		BlendMode blendMode = BlendMode.Opaque;
		if (oldShader.name.Contains("/Transparent/Cutout/"))
		{
			blendMode = BlendMode.Cutout;
		}
		else if (oldShader.name.Contains("/Transparent/"))
		{
			// NOTE: legacy shaders did not provide physically based transparency
			// therefore Fade mode
			blendMode = BlendMode.Fade;
		}
		material.SetFloat("_Mode", (float)blendMode);

		//DetermineWorkflow( MaterialEditor.GetMaterialProperties (new Material[] { material }) );
		DetermineWorkflow( material );
		MaterialChanged(material, m_WorkflowMode);
	}

	void BlendModePopup()
	{
		EditorGUI.showMixedValue = blendMode.hasMixedValue;
		var mode = (BlendMode)blendMode.floatValue;

		EditorGUI.BeginChangeCheck();
		mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
		if (EditorGUI.EndChangeCheck())
		{
			m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
			blendMode.floatValue = (float)mode;
		}

		EditorGUI.showMixedValue = false;
	}

	void DoAlbedoArea(Material material)
	{
		m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
		if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
		{
			m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText.text, MaterialEditor.kMiniTextureFieldLabelIndentLevel+1);
		}
	}

	void DoEmissionArea(Material material)
	{
		float brightness = emissionColorForRendering.colorValue.maxColorComponent;
		bool showHelpBox = !HasValidEmissiveKeyword(material);
		bool showEmissionColorAndGIControls = brightness > 0.0f;
		
		bool hadEmissionTexture = emissionMap.textureValue != null;

		// Texture and HDR color controls
		m_MaterialEditor.TexturePropertyWithHDRColor(Styles.emissionText, emissionMap, emissionColorForRendering, m_ColorPickerHDRConfig, false);

		// If texture was assigned and color was black set color to white
		if (emissionMap.textureValue != null && !hadEmissionTexture && brightness <= 0f)
			emissionColorForRendering.colorValue = Color.white;

		// Dynamic Lightmapping mode
		if (showEmissionColorAndGIControls)
		{
			bool shouldEmissionBeEnabled = ShouldEmissionBeEnabled(emissionColorForRendering.colorValue);
			EditorGUI.BeginDisabledGroup(!shouldEmissionBeEnabled);

			m_MaterialEditor.LightmapEmissionProperty (MaterialEditor.kMiniTextureFieldLabelIndentLevel + 1);

			EditorGUI.EndDisabledGroup();
		}

		if (showHelpBox)
		{
			EditorGUILayout.HelpBox(Styles.emissiveWarning.text, MessageType.Warning);
		}
	}

	void DoSpecularMetallicArea()
	{
		if (m_WorkflowMode == WorkflowMode.Specular)
		{
			if (specularMap.textureValue == null)
				m_MaterialEditor.TexturePropertyTwoLines(Styles.specularMapText, specularMap, specularColor, Styles.smoothnessText, smoothness);
			else
				m_MaterialEditor.TexturePropertySingleLine(Styles.specularMapText, specularMap);

		}
		else if (m_WorkflowMode == WorkflowMode.Metallic)
		{
			if (metallicMap.textureValue == null)
				m_MaterialEditor.TexturePropertyTwoLines(Styles.metallicMapText, metallicMap, metallic, Styles.smoothnessText, smoothness);
			else
				m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap);
		}
	}

	public static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
	{
		switch (blendMode)
		{
			case BlendMode.Opaque:
				material.SetOverrideTag("RenderType", "");
				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
				material.SetInt("_ZWrite", 1);
				material.DisableKeyword("_ALPHATEST_ON");
				material.DisableKeyword("_ALPHABLEND_ON");
				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
				material.renderQueue = -1;
				break;
			case BlendMode.Cutout:
				material.SetOverrideTag("RenderType", "TransparentCutout");
				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
				material.SetInt("_ZWrite", 1);
				material.EnableKeyword("_ALPHATEST_ON");
				material.DisableKeyword("_ALPHABLEND_ON");
				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
				material.renderQueue = 2450;
				break;
			case BlendMode.Fade:
				material.SetOverrideTag("RenderType", "Transparent");
				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
				material.SetInt("_ZWrite", 1);
				material.DisableKeyword("_ALPHATEST_ON");
				material.EnableKeyword("_ALPHABLEND_ON");
				material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
				material.renderQueue = 2451; // Not 3000, Support shadow.
				break;
			case BlendMode.Transparent:
				material.SetOverrideTag("RenderType", "Transparent");
				material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
				material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
				material.SetInt("_ZWrite", 1);
				material.DisableKeyword("_ALPHATEST_ON");
				material.DisableKeyword("_ALPHABLEND_ON");
				material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
				material.renderQueue = 2451; // Not 3000, Support shadow.
				break;
		}
	}
	
	static bool ShouldEmissionBeEnabled (Color color)
	{
		return color.maxColorComponent > (0.1f / 255.0f);
	}

	static void SetMaterialKeywords(Material material, WorkflowMode workflowMode)
	{
		// Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
		// (MaterialProperty value might come from renderer material property block)
		SetKeyword (material, "_NORMALMAP", material.GetTexture ("_BumpMap") || material.GetTexture ("_DetailNormalMap"));
		if (workflowMode == WorkflowMode.Specular)
			SetKeyword (material, "_SPECGLOSSMAP", material.GetTexture ("_SpecGlossMap"));
		else if (workflowMode == WorkflowMode.Metallic)
			SetKeyword (material, "_METALLICGLOSSMAP", material.GetTexture ("_MetallicGlossMap"));
		SetKeyword (material, "_PARALLAXMAP", material.GetTexture ("_ParallaxMap"));
		SetKeyword (material, "_DETAIL_MULX2", material.GetTexture ("_DetailAlbedoMap") || material.GetTexture ("_DetailNormalMap"));

		bool shouldEmissionBeEnabled = ShouldEmissionBeEnabled (material.GetColor("_EmissionColor"));
		SetKeyword (material, "_EMISSION", shouldEmissionBeEnabled);

		// Setup lightmap emissive flags
		MaterialGlobalIlluminationFlags flags = material.globalIlluminationFlags;
		if ((flags & (MaterialGlobalIlluminationFlags.BakedEmissive | MaterialGlobalIlluminationFlags.RealtimeEmissive)) != 0)
		{
			flags &= ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
			if (!shouldEmissionBeEnabled)
				flags |= MaterialGlobalIlluminationFlags.EmissiveIsBlack;

			material.globalIlluminationFlags = flags;
		}
	}

	bool HasValidEmissiveKeyword (Material material)
	{
		// Material animation might be out of sync with the material keyword.
		// So if the emission support is disabled on the material, but the property blocks have a value that requires it, then we need to show a warning.
		// (note: (Renderer MaterialPropertyBlock applies its values to emissionColorForRendering))
		bool hasEmissionKeyword = material.IsKeywordEnabled ("_EMISSION");
		if (!hasEmissionKeyword && ShouldEmissionBeEnabled (emissionColorForRendering.colorValue))
			return false;
		else
			return true;
	}

	static void MaterialChanged(Material material, WorkflowMode workflowMode)
	{
		SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));

		SetMaterialKeywords(material, workflowMode);
	}

	static void SetKeyword(Material m, string keyword, bool state)
	{
		if (state)
			m.EnableKeyword (keyword);
		else
			m.DisableKeyword (keyword);
	}
}

} // namespace ShaderKits