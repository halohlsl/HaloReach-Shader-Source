/*
EMBLEM_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2009. all rights reserved.
12/17/2009 11:04:02 AM (ctchou)
*/


PIXEL_FLOAT(float4,		foreground_color,		k_ps_foreground_color,		32,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		midground_color,		k_ps_midground_color,		33,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		background_color,		k_ps_background_color,		34,	1,	emblem_shader, command_buffer_cache_unknown)

PIXEL_FLOAT(float3x2,	foreground_xform[2],	k_foreground_xform,			36,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		foreground_params[2],	k_foreground_params,		40,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_FLOAT(float3x2,	midground_xform[2],		k_midground_xform,			42,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		midground_params[2],	k_midground_params,			46,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_FLOAT(float3x2,	background_xform[2],	k_background_xform,			48,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		background_params[2],	k_background_params,		52,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_SAMPLER(sampler,	foreground0_sampler,	k_ps_foreground0_sampler,	0,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	foreground1_sampler,	k_ps_foreground1_sampler,	1,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	midground0_sampler,		k_ps_midground0_sampler,	2,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	midground1_sampler,		k_ps_midground1_sampler,	3,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	background0_sampler,	k_ps_background0_sampler,	4,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	background1_sampler,	k_ps_background1_sampler,	5,	1,	emblem_shader, command_buffer_cache_unknown)


