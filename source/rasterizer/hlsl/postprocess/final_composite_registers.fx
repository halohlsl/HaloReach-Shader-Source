
PIXEL_FLOAT(float4,		tone_curve_constants,		k_ps_tone_curve_constants,		3,		1,	final_composite, command_buffer_cache_unknown)		// tone curve:		max, linear, quadratic, cubic terms
PIXEL_FLOAT(float4,		player_window_constants,	k_ps_player_window_constants,	4,		1,	final_composite, command_buffer_cache_unknown)		// weapon zoom:		x, y, (left top corner), z,w (width, height);
PIXEL_FLOAT(float4,		depth_constants,			k_ps_depth_constants,			5,		1,	final_composite, command_buffer_cache_unknown)		// depth of field:	1/near,  -(far-near)/(far*near), focus distance, aperture
PIXEL_FLOAT(float4,		depth_constants2,			k_ps_depth_constants2,			6,		1,	final_composite, command_buffer_cache_unknown)		// depth of field:	focus half width

PIXEL_FLOAT(float4x3,	color_matrix,				k_ps_color_matrix,				129,	3,	final_composite, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		gamma,						k_ps_gamma,						132,	1,	final_composite, command_buffer_cache_unknown)

PIXEL_FLOAT(float4,		noise_params,				k_ps_noise_params,				136,	1,	final_composite, command_buffer_cache_unknown)		//	{ dark_noise; bright_noise; 1.0f - dark_noise; 0.0; }

VERTEX_FLOAT(float4,	noise_space_xform,			k_vs_noise_space_xform,			150,	1,	final_composite, command_buffer_cache_unknown)
VERTEX_FLOAT(float4,	pixel_space_xform,			k_vs_pixel_space_xform,			151,	1,	final_composite, command_buffer_cache_unknown)


PIXEL_SAMPLER(sampler2D,	surface_sampler,		k_ps_surface_sampler,		0,	1,	final_composite, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler2D,	dark_surface_sampler,	k_ps_dark_surface_sampler,	1,	1,	final_composite, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler2D,	bloom_sampler,			k_ps_bloom_sampler,			2,	1,	final_composite, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler2D,	depth_sampler,			k_ps_depth_sampler,			3,	1,	final_composite, command_buffer_cache_unknown)				// depth of field
PIXEL_SAMPLER(sampler2D,	blur_sampler,			k_ps_blur_sampler,			4,	1,	final_composite, command_buffer_cache_unknown)				// depth of field
PIXEL_SAMPLER(sampler2D,	blur_grade_sampler,		k_ps_blur_grade_sampler,	5,	1,	final_composite, command_buffer_cache_unknown)				// weapon zoom
PIXEL_SAMPLER(sampler2D,	prev_sampler,			k_ps_prev_sampler,			6,	1,	final_composite, command_buffer_cache_unknown)				// antialiasing
PIXEL_SAMPLER(sampler2D,	noise_sampler,			k_ps_noise_sampler,			7,	1,	final_composite, command_buffer_cache_unknown)				// noise







