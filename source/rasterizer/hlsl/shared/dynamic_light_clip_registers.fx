#if DX_VERSION == 11

CBUFFER_BEGIN(DynamicLightClipVS)
	CBUFFER_CONST_ARRAY(DynamicLightClipVS,	float4,		v_dynamic_light_clip_plane, [6],	k_vs_dynamic_light_clip_plane)
CBUFFER_END

#endif
