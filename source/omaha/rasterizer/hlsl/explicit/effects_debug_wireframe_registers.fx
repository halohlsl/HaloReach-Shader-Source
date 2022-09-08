#if DX_VERSION == 9

DECLARE_PARAMETER(float4, debugColor, c58);

#elif DX_VERSION == 11

CBUFFER_BEGIN(EffectsDebugWireframePS)
	CBUFFER_CONST(EffectsDebugWireframePS,		float4,		debugColor,		k_ps_effects_debug_wireframe_debug_color)
CBUFFER_END

#endif
