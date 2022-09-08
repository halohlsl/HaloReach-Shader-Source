#if DX_VERSION == 9

DECLARE_PARAMETER(sampler2D, source_sampler, s0);
DECLARE_PARAMETER(sampler2D, source_lowres_sampler, s1);
DECLARE_PARAMETER(sampler2D, palette_sampler, s2);

DECLARE_PARAMETER(float4, quad_tiling, c16);			// quad tiling parameters (x, 1/x, y, 1/y)
DECLARE_PARAMETER(float4, position_transform, c17);		// position transform from quad coordinates [0,x], [0,y] -> screen coordinates
DECLARE_PARAMETER(float4, texture_transform, c18);		// texture transform from quad coordinates [0,x], [0,y] -> texture coordinates
DECLARE_PARAMETER(float4, tangent_transform, c19);		// tangent space transform from quad coordinates into projected tangent space
DECLARE_PARAMETER(float4, camera_space_light, c20);		// camera space light direction

DECLARE_PARAMETER(float4, light_params, c6);			// blur ps_scale, total ps_scale,
DECLARE_PARAMETER(float4, light_spread, c7);
DECLARE_PARAMETER(float4, p_lighting_constant_7, c8);
DECLARE_PARAMETER(float4, p_lighting_constant_8, c9);
DECLARE_PARAMETER(float4, p_lighting_constant_9, c10);

#elif DX_VERSION == 11

CBUFFER_BEGIN(LitParticleOverdrawApplyVS)
	CBUFFER_CONST(LitParticleOverdrawApplyVS,		float4, 	quad_tiling, 			k_vs_lit_particle_overdraw_apply_quad_tiling)
	CBUFFER_CONST(LitParticleOverdrawApplyVS,		float4, 	position_transform, 	k_vs_lit_particle_overdraw_apply_position_transform)
	CBUFFER_CONST(LitParticleOverdrawApplyVS,		float4, 	texture_transform, 		k_vs_lit_particle_overdraw_apply_texture_transform)
	CBUFFER_CONST(LitParticleOverdrawApplyVS,		float4, 	tangent_transform, 		k_vs_lit_particle_overdraw_apply_tangent_transform)
	CBUFFER_CONST(LitParticleOverdrawApplyVS,		float4, 	camera_space_light, 	k_vs_lit_particle_overdraw_apply_camera_space_light)
CBUFFER_END

CBUFFER_BEGIN(LitParticleOverdrawApplyPS)
	CBUFFER_CONST(LitParticleOverdrawApplyPS,			float4, 	light_params, 			k_ps_lit_particle_overdraw_apply_light_params)
	CBUFFER_CONST(LitParticleOverdrawApplyPS,			float4, 	light_spread, 			k_ps_lit_particle_overdraw_apply_light_spread)
	//CBUFFER_CONST(LitParticleOverdrawApplyPS,			float4, 	p_lighting_constant_7, 	k_ps_lit_particle_overdraw_apply_lighting_constant_7)
	//CBUFFER_CONST(LitParticleOverdrawApplyPS,			float4, 	p_lighting_constant_8, 	k_ps_lit_particle_overdraw_apply_lighting_constant_8)
	//CBUFFER_CONST(LitParticleOverdrawApplyPS,			float4, 	p_lighting_constant_9, 	k_ps_lit_particle_overdraw_apply_lighting_constant_9)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler, 			k_ps_lit_particle_overdraw_source_sampler,				0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_lowres_sampler, 		k_ps_lit_particle_overdraw_source_lowres_sampler,		1)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	palette_sampler, 			k_ps_lit_particle_overdraw_palette_sampler,				2)

#endif
