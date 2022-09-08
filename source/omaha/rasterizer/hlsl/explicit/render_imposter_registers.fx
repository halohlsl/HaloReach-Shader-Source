#if DX_VERSION == 9

// define constants for clouds
SAMPLER_CONSTANT(k_ps_texture_vmf_diffuse, 0)
SAMPLER_CONSTANT(k_ps_texture_cloud, 1)

SAMPLER_CONSTANT(k_ps_sampler_imposter_cubemap_0, 2)
SAMPLER_CONSTANT(k_ps_sampler_imposter_cubemap_1, 3)
PIXEL_CONSTANT(float4, k_ps_cubemap_constants, 180)
PIXEL_CONSTANT(float4, k_ps_imposter_blend_alpha, 181)
PIXEL_CONSTANT(float4, k_ps_imposter_adjustment_constants, 182)

VERTEX_CONSTANT(float4, k_vs_big_battle_squad_constants, 232)

// PC only constants
VERTEX_CONSTANT(float4, k_vs_big_battle_squad_positon_scale, 233)
VERTEX_CONSTANT(float4, k_vs_big_battle_squad_foward, 234)
VERTEX_CONSTANT(float4, k_vs_big_battle_squad_left, 235)
VERTEX_CONSTANT(float4, k_vs_big_battle_squad_velocity, 236)

#elif DX_VERSION == 11

CBUFFER_BEGIN(RenderImposterVS)
	CBUFFER_CONST(RenderImposterVS,		float4, 	k_vs_big_battle_squad_constants, 		k_vs_render_imposter_big_battle_squad_constants)
	CBUFFER_CONST(RenderImposterVS,		float4, 	k_vs_big_battle_squad_positon_scale, 	k_vs_render_imposter_big_battle_squad_position_scale)
	CBUFFER_CONST(RenderImposterVS,		float4, 	k_vs_big_battle_squad_foward, 			k_vs_render_imposter_big_battle_squad_forward)
	CBUFFER_CONST(RenderImposterVS,		float4, 	k_vs_big_battle_squad_left, 			k_vs_render_imposter_big_battle_squad_left)
	CBUFFER_CONST(RenderImposterVS,		float4, 	k_vs_big_battle_squad_velocity, 		k_vs_render_imposter_big_battle_squad_velocity)
CBUFFER_END

CBUFFER_BEGIN(RenderImposterPS)
	CBUFFER_CONST(RenderImposterPS, 	float4, 	k_ps_cubemap_constants, 				k_ps_render_imposter_cubemap_constants)
	CBUFFER_CONST(RenderImposterPS,		float4, 	k_ps_imposter_blend_alpha, 				k_ps_render_imposter_blend_alpha)
	CBUFFER_CONST(RenderImposterPS,		float4, 	k_ps_imposter_adjustment_constants, 	k_ps_render_imposter_adjustment_constants)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,		k_ps_texture_vmf_diffuse, 			k_ps_render_imposter_texture_vmf_diffuse,	0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		k_ps_texture_cloud, 				k_ps_render_imposter_texture_cloud,			1)
PIXEL_TEXTURE_AND_SAMPLER(_CUBE,	k_ps_sampler_imposter_cubemap_0, 	k_ps_render_imposter_texture_cubemap_0,		2)
PIXEL_TEXTURE_AND_SAMPLER(_CUBE,	k_ps_sampler_imposter_cubemap_1, 	k_ps_render_imposter_texture_cubemap_1,		3)

#endif
