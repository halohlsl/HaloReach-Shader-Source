#if DX_VERSION == 9

#ifdef PIXEL_SHADER
	PIXEL_CONSTANT(s_atmosphere_constants, k_ps_atmosphere_constants, c200);
	PIXEL_CONSTANT(s_fog_light_constants, k_ps_atmosphere_fog_constants, c204);
	PIXEL_CONSTANT(s_atmosphere_precomputed_LUT_constants, k_ps_atmosphere_lut_constants, c232);
	PIXEL_CONSTANT(float4x4,	 k_ps_view_xform_inverse,	c213);			// ###XWAN ###CTCHOU $PERF make this c212...   don't straddle 4-constant boundaries if you don't have to
#endif // PIXEL_SHADER

#ifdef VERTEX_SHADER
	VERTEX_CONSTANT(float4x4, k_vs_camera_to_world, c16);
	VERTEX_CONSTANT(float4x4, k_vs_projective_to_world, c20);
	VERTEX_CONSTANT(float4x4, k_vs_camera_to_projective, c24);
	VERTEX_CONSTANT(float4x4, k_vs_world_to_projective, c28);

	VERTEX_CONSTANT(s_atmosphere_constants, k_vs_atmosphere_constants, c232);		// should lie on top of v_atmosphere_constant_0 / k_vs_atmosphere_constant_0
#endif // VERTEX_SHADER

sampler k_ps_screen_atm_fog_sampler_depth_buffer : register(s1);
sampler k_ps_screen_atm_fog_sampler_color_buffer : register(s2);
sampler k_ps_screen_atm_fog_sampler_fog_table : register(s3);

#elif DX_VERSION == 11

#include "shared\atmosphere_structs.fx"
#include "shared\atmosphere_registers.fx"

CBUFFER_BEGIN(ScreenAtmFogPS)
	CBUFFER_CONST(ScreenAtmFogPS,	s_atmosphere_constants, 					k_ps_atmosphere_constants, 			k_ps_screen_atm_fog_constants)
	CBUFFER_CONST(ScreenAtmFogPS,	s_fog_light_constants, 						k_ps_atmosphere_fog_constants,		k_ps_screen_atm_fog_fog_constants)
	CBUFFER_CONST(ScreenAtmFogPS,	s_atmosphere_precomputed_LUT_constants, 	k_ps_atmosphere_lut_constants,		k_ps_screen_atm_fog_lut_constants)
	CBUFFER_CONST(ScreenAtmFogPS,	float4x4,	 								k_ps_view_xform_inverse,			k_ps_screen_atm_fog_view_xform_inverse)
CBUFFER_END

CBUFFER_BEGIN(ScreenAtmFogVS)
	CBUFFER_CONST(ScreenAtmFogVS,	float4x4, 									k_vs_camera_to_world,				k_vs_screen_atm_fog_camera_to_world)
	CBUFFER_CONST(ScreenAtmFogVS,	float4x4, 									k_vs_projective_to_world,			k_vs_screen_atm_fog_projective_to_world)
	CBUFFER_CONST(ScreenAtmFogVS,	float4x4, 									k_vs_camera_to_projective,			k_vs_screen_atm_fog_camera_to_projective)
	CBUFFER_CONST(ScreenAtmFogVS,	float4x4, 									k_vs_world_to_projective,			k_vs_screen_atm_fog_world_to_projective)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D, 	k_ps_screen_atm_fog_sampler_depth_buffer,	k_ps_screen_atm_fog_sampler_depth_buffer,	1)
PIXEL_TEXTURE_AND_SAMPLER(_2D, 	k_ps_screen_atm_fog_sampler_color_buffer,	k_ps_screen_atm_fog_sampler_color_buffer,	2)
PIXEL_TEXTURE_AND_SAMPLER(_2D, 	k_ps_screen_atm_fog_sampler_fog_table,		k_ps_screen_atm_fog_sampler_fog_table,		3)

#endif
