/*
PATCHY_FOG_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
4/05/2007 9:15:00 AM (kuttas)
	
*/


// Noise texture sampled for fog density
PIXEL_SAMPLER(sampler,	k_ps_sampler_tex_noise,			k_ps_sampler_tex_noise,			0,	1,	patchy_fog, command_buffer_cache_unknown)

// Scene depth texture sampled to fade fog near scene intersections
PIXEL_SAMPLER(sampler,	k_ps_sampler_tex_scene_depth,	k_ps_sampler_tex_scene_depth,	1,	1,	patchy_fog, command_buffer_cache_unknown)

// Scene depth texture sampled to fade fog near scene intersections
PIXEL_SAMPLER(sampler,	k_ps_sampler_patchy_buffer0,		k_ps_sampler_patchy_buffer0,		2,	1,	patchy_fog, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	k_ps_sampler_patchy_buffer1,		k_ps_sampler_patchy_buffer1,		3,	1,	patchy_fog, command_buffer_cache_unknown)


PIXEL_FLOAT(float4,		k_ps_inverse_z_transform,		k_ps_inverse_z_transform,	32, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_texcoord_basis,			k_ps_texcoord_basis,		33, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_attenuation_data,			k_ps_attenuation_data,		34, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_eye_position,				k_ps_eye_position,			35, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_window_pixel_bounds,		k_ps_window_pixel_bounds,	36, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tint_color,				k_ps_tint_color,			37,	1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tint_color2,				k_ps_tint_color2,			38,	1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_optical_depth_scale,		k_ps_optical_depth_scale,	39,	1, patchy_fog, command_buffer_cache_unknown)

PIXEL_FLOAT(float4,		k_ps_sheet_fade_factors[2],		k_ps_sheet_fade_factors,	40, 2, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_sheet_depths[2],			k_ps_sheet_depths,			42, 2, patchy_fog, command_buffer_cache_unknown)

PIXEL_FLOAT(float4,		k_ps_tex_coord_transform0,		k_ps_tex_coord_transform0,	44, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform1,		k_ps_tex_coord_transform1,	45, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform2,		k_ps_tex_coord_transform2,	46, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform3,		k_ps_tex_coord_transform3,	47, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform4,		k_ps_tex_coord_transform4,	48, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform5,		k_ps_tex_coord_transform5,	49, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform6,		k_ps_tex_coord_transform6,	50, 1, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_tex_coord_transform7,		k_ps_tex_coord_transform7,	51, 1, patchy_fog, command_buffer_cache_unknown)

PIXEL_FLOAT(float4,		k_ps_texcoord_offsets[4],		k_ps_texcoord_offsets,		80, 4, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_texcoord_x_scale[4],		k_ps_texcoord_x_scale,		84, 4, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_texcoord_y_scale[4],		k_ps_texcoord_y_scale,		88, 4, patchy_fog, command_buffer_cache_unknown)

PIXEL_FLOAT(float4,		k_ps_height_fade_scales[2],		k_ps_height_fade_scales,	92, 2, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_height_fade_offset[2],		k_ps_height_fade_offset,	94, 2, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_depth_fade_scales[2],		k_ps_depth_fade_scales,		96, 2, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_depth_fade_offset[2],		k_ps_depth_fade_offset,		98, 2, patchy_fog, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		k_ps_sheet_fade[2],				k_ps_sheet_fade,			100, 2, patchy_fog, command_buffer_cache_unknown)

VERTEX_FLOAT(float4,	k_vs_z_epsilon,					k_vs_z_epsilon,					239, 1, patchy_fog, command_buffer_cache_unknown)
VERTEX_FLOAT(float4x4,	k_vs_proj_to_world_relative,	k_vs_proj_to_world_relative,	240, 4, patchy_fog, command_buffer_cache_unknown)


#define k_ps_sphere_warp_scale (k_ps_optical_depth_scale.y)
#define k_ps_projective_to_tangent_space	(k_ps_optical_depth_scale.zw)

