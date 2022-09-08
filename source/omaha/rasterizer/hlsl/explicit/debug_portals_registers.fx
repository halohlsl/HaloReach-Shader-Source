#if DX_VERSION == 9

float4 color : register(c2);

sampler	vector_map;

#elif DX_VERSION == 11

CBUFFER_BEGIN(DebugPortalsPS)
	CBUFFER_CONST(DebugPortalsPS,		float4,		color,		k_ps_debug_portals_color)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	vector_map, 	k_ps_debug_portals_vector_map,		0)

#endif
