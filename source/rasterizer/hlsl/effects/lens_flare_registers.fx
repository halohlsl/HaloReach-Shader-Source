#if DX_VERSION == 9

sampler2D source_sampler : register(s0);

// x is modulation factor, y is tint power, z is brightness, w unused
PIXEL_CONSTANT(float4, modulation_factor, c50);
PIXEL_CONSTANT(float4, tint_color, c51);
PIXEL_CONSTANT( float4, scale, c2);
VERTEX_CONSTANT(float4, center_rotation, c240);		// center(x,y), theta
VERTEX_CONSTANT(float4, flare_scale, c241);			// scale(x, y), global scale

#elif DX_VERSION == 11

CBUFFER_BEGIN(LensFlareVS)
	CBUFFER_CONST(LensFlareVS,		float4, 	center_rotation,				k_vs_lens_flare_center_rotation)
	CBUFFER_CONST(LensFlareVS,		float4, 	flare_scale, 					k_vs_lens_flare_flare_scale)
CBUFFER_END

CBUFFER_BEGIN(LensFlarePS)
	CBUFFER_CONST(LensFlarePS,		float4, 	modulation_factor, 				k_ps_lens_flare_modulation_factor)
	CBUFFER_CONST(LensFlarePS,		float4, 	tint_color,						k_ps_lens_flare_tint_color)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler, 		k_ps_lens_flare_source_sampler,		0)

#endif
