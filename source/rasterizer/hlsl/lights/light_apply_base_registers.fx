#if DX_VERSION == 9

sampler depth_sampler : register(s0);
sampler albedo_sampler : register(s1);
sampler normal_sampler : register(s2);
sampler specular_curve_sampler : register(s3);
sampler gel_sampler : register(s4);
sampler	shadow_depth_map_1	: register(s5);

PIXEL_CONSTANT(float4x4, screen_to_relative_world, c1);		// p_lighting_constant_0 - p_lighting_constant_3,	maps (pixel, depth) to world space coordinates with the origin at the light center

PIXEL_CONSTANT(float4, light_colour_falloff_power, c4)
PIXEL_CONSTANT(float4, light_attenuation, c5)
PIXEL_CONSTANT(float4, camera_to_light, c6)

PIXEL_CONSTANT(float3x3, light_rotation, c8);				// p_lighting_constant_7 - p_lighting_constant_9

PIXEL_CONSTANT(float4, specular_color_normal, c11);  //w : specular steepness
PIXEL_CONSTANT(float4, specular_color_gazing, c12);  //w: specular coeff
PIXEL_CONSTANT(float4, material_coeff, c13);   //x: diffuse, y: roughness offset, z: albedo blend, w: NONE

PIXEL_CONSTANT(float, cheap_albedo_blend, c13);

PIXEL_CONSTANT(float4x4, screen_light_shadow_matrix, c200);
PIXEL_CONSTANT(float4, screen_light_shadow_aux_constant_0, c204);
PIXEL_CONSTANT(float4, screen_light_shadow_aux_constant_1, c205);

#elif DX_VERSION == 11

CBUFFER_BEGIN(LightApplyBasePS)
	CBUFFER_CONST(LightApplyBasePS,		float4x4, 		screen_to_relative_world,				k_ps_light_apply_base_screen_to_relative_world)
	CBUFFER_CONST(LightApplyBasePS,		float4,			light_colour_falloff_power,				k_ps_light_apply_base_light_colour)
	CBUFFER_CONST(LightApplyBasePS,		float4,			light_attenuation,						k_ps_light_apply_base_light_attenuation)
	CBUFFER_CONST(LightApplyBasePS,		float4,			camera_to_light,						k_ps_light_apply_base_camera_to_light)
	CBUFFER_CONST(LightApplyBasePS,		float3x3, 		light_rotation,							k_ps_light_apply_base_light_rotation)
	CBUFFER_CONST(LightApplyBasePS,		float,			light_rotation_pad,						k_ps_light_apply_base_light_rotation_pad)
	CBUFFER_CONST(LightApplyBasePS,		float4, 		specular_color_normal,					k_ps_light_apply_base_specular_color_normal)
	CBUFFER_CONST(LightApplyBasePS,		float4, 		specular_color_gazing,					k_ps_light_apply_base_specular_color_gazing)
	CBUFFER_CONST(LightApplyBasePS,		float4, 		material_coeff,							k_ps_light_apply_base_material_coeff)
	CBUFFER_CONST(LightApplyBasePS,		float4x4,		screen_light_shadow_matrix,				k_ps_light_apply_base_screen_light_shadow_matrix)
	CBUFFER_CONST(LightApplyBasePS,		float4,			screen_light_shadow_aux_constant_0,		k_ps_light_apply_base_screen_light_shadow_aux_constant_0)
	CBUFFER_CONST(LightApplyBasePS,		float4,			screen_light_shadow_aux_constant_1,		k_ps_light_apply_base_screen_light_shadow_aux_constant_1)
CBUFFER_END

SHADER_CONST_ALIAS(LightApplyBasePS,	float,			cheap_albedo_blend,						material_coeff.x,		k_ps_light_apply_base_cheap_albedo_blend,	k_ps_light_apply_base_material_coeff,	0)

PIXEL_TEXTURE_AND_SAMPLER(_2D,		depth_sampler,				k_ps_light_apply_base_depth_sampler,			0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		albedo_sampler,				k_ps_light_apply_base_albedo_sampler,			1)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		normal_sampler,				k_ps_light_apply_base_normal_sampler,			2)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		specular_curve_sampler,		k_ps_light_apply_base_specular_curve_sampler,	3)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		gel_sampler,				k_ps_light_apply_base_gel_sampler,				4)
PIXEL_TEXTURE_AND_SAMPLER(_CUBE,	gel_sampler_cube,			k_ps_light_apply_base_gel_sampler_cube,			4)
PIXEL_TEXTURE_AND_SAMPLER(_2D,		shadow_depth_map_1,			k_ps_light_apply_base_shadow_depth_map_1,		5)

#endif
