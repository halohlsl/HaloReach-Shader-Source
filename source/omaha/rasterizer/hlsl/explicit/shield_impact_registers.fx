/*
SHIELD_IMPACT_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
4/05/2007 9:15:00 AM (kuttas)

*/

#if DX_VERSION == 9

// ensure that these don't conflict with oneshot/persist registers

VERTEX_CONSTANT(float4, vertex_params,	10)
VERTEX_CONSTANT(float4, vertex_params2, 11)
VERTEX_CONSTANT(float4, impact0_params, 8)
VERTEX_CONSTANT(float4, impact1_params, 9)

PIXEL_CONSTANT(float4, impact0_color,		108)			// used -- dynamic
PIXEL_CONSTANT(float4, impact1_color,		109)			// unused

PIXEL_CONSTANT(float4, plasma_offsets,		112)			// used -- dynamic: linear with time
PIXEL_CONSTANT(float4, edge_glow,			113)			// used -- dynamic: user function
PIXEL_CONSTANT(float4, plasma_color,		114)			// used -- dynamic: user function
PIXEL_CONSTANT(float4, plasma_edge_color,	115)			// used -- dynamic: user function (actually the delta between plasma_color and plasma_edge_color)

PIXEL_CONSTANT(float4, edge_scales,			116)			// used -- static
PIXEL_CONSTANT(float4, edge_offsets,		117)			// used -- static
PIXEL_CONSTANT(float4, plasma_scales,		118)			// used -- static
PIXEL_CONSTANT(float4, depth_fade_params,	119)			// used -- static

// noise textures
PIXEL_SAMPLER_CONSTANT(shield_impact_noise_texture1, 0)
PIXEL_SAMPLER_CONSTANT(shield_impact_noise_texture2, 1)

VERTEX_SAMPLER_CONSTANT(shield_impact_noise_texture1, 0)
VERTEX_SAMPLER_CONSTANT(shield_impact_noise_texture2, 1)

#elif DX_VERSION == 11

CBUFFER_BEGIN(ShieldImpactVS)
	CBUFFER_CONST(ShieldImpactVS,		float4, 	vertex_params,			k_vs_shield_impact_vertex_params)
	CBUFFER_CONST(ShieldImpactVS,		float4, 	vertex_params2, 		k_vs_shield_impact_vertex_params2)
	CBUFFER_CONST(ShieldImpactVS,		float4, 	impact0_params, 		k_vs_shield_impact_impact0_params)
	CBUFFER_CONST(ShieldImpactVS,		float4, 	impact1_params, 		k_vs_shield_impact_impact1_params)
CBUFFER_END

VERTEX_TEXTURE_AND_SAMPLER(_2D,	vs_shield_impact_noise_texture1, 	k_vs_shield_impact_sampler_impact_noise_texture1,	 		0)
VERTEX_TEXTURE_AND_SAMPLER(_2D,	vs_shield_impact_noise_texture2, 	k_vs_shield_impact_sampler_impact_noise_texture2,		 	1)

CBUFFER_BEGIN(ShieldImpactPS)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	impact0_color,			k_ps_shield_impact_impact0_color)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	impact1_color,		    k_ps_shield_impact_impact1_color)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	plasma_offsets,		    k_ps_shield_impact_plasma_offsets)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	edge_glow,			    k_ps_shield_impact_edge_glow)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	plasma_color,		    k_ps_shield_impact_plasma_color)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	plasma_edge_color,	    k_ps_shield_impact_plasma_edge_color)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	edge_scales,		    k_ps_shield_impact_edge_scales)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	edge_offsets,		    k_ps_shield_impact_edge_offsets)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	plasma_scales,		    k_ps_shield_impact_plasma_scales)
	CBUFFER_CONST(ShieldImpactPS,			float4, 	depth_fade_params,	    k_ps_shield_impact_depth_fade_params)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	shield_impact_noise_texture1, 		k_ps_shield_impact_sampler_impact_noise_texture1,	 0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	shield_impact_noise_texture2, 		k_ps_shield_impact_sampler_impact_noise_texture2,	 1)

#endif
