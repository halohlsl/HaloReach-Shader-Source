/*
EMBLEM_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2009. all rights reserved.
12/17/2009 11:04:02 AM (ctchou)
*/

#if DX_VERSION == 9

PIXEL_FLOAT(float4,		foreground_color,		k_ps_emblem_foreground_color,		32,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		midground_color,		k_ps_emblem_midground_color,		33,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		background_color,		k_ps_emblem_background_color,		34,	1,	emblem_shader, command_buffer_cache_unknown)

PIXEL_FLOAT(float3x2,	foreground_xform[2],	k_ps_emblem_foreground_xform,			36,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		foreground_params[2],	k_ps_emblem_foreground_params,		40,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_FLOAT(float3x2,	midground_xform[2],		k_ps_emblem_midground_xform,			42,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		midground_params[2],	k_ps_emblem_midground_params,			46,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_FLOAT(float3x2,	background_xform[2],	k_ps_emblem_background_xform,			48,	4,	emblem_shader, command_buffer_cache_unknown)
PIXEL_FLOAT(float4,		background_params[2],	k_ps_emblem_background_params,		52,	2,	emblem_shader, command_buffer_cache_unknown)		// vector_sharpness, antialias_tweak, expand, mix weight

PIXEL_SAMPLER(sampler,	foreground0_sampler,	k_ps_emblem_foreground0_sampler,	0,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	foreground1_sampler,	k_ps_emblem_foreground1_sampler,	1,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	midground0_sampler,		k_ps_emblem_midground0_sampler,		2,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	midground1_sampler,		k_ps_emblem_midground1_sampler,		3,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	background0_sampler,	k_ps_emblem_background0_sampler,	4,	1,	emblem_shader, command_buffer_cache_unknown)
PIXEL_SAMPLER(sampler,	background1_sampler,	k_ps_emblem_background1_sampler,	5,	1,	emblem_shader, command_buffer_cache_unknown)

#elif DX_VERSION == 11

CBUFFER_BEGIN(EmblemPS)
	CBUFFER_CONST(EmblemPS,			float4,			foreground_color,			k_ps_emblem_foreground_color)
	CBUFFER_CONST(EmblemPS,			float4,			midground_color,			k_ps_emblem_midground_color)
	CBUFFER_CONST(EmblemPS,			float4,			background_color,			k_ps_emblem_background_color)
	CBUFFER_CONST_ARRAY(EmblemPS,	float3x2,		foreground_xform, [2],		k_ps_emblem_foreground_xform)
	CBUFFER_CONST_ARRAY(EmblemPS,	float4,			foreground_params, [2],		k_ps_emblem_foreground_params)
	CBUFFER_CONST_ARRAY(EmblemPS,	float3x2,		midground_xform, [2],		k_ps_emblem_midground_xform)
	CBUFFER_CONST_ARRAY(EmblemPS,	float4,			midground_params, [2],		k_ps_emblem_midground_params)
	CBUFFER_CONST_ARRAY(EmblemPS,	float3x2,		background_xform, [2],		k_ps_emblem_background_xform)
	CBUFFER_CONST_ARRAY(EmblemPS,	float4,			background_params,[2],		k_ps_emblem_background_params)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	foreground0_sampler,	k_ps_emblem_foreground0_sampler,	4)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	foreground1_sampler,	k_ps_emblem_foreground1_sampler,	5)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	midground0_sampler,		k_ps_emblem_midground0_sampler,		6)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	midground1_sampler,		k_ps_emblem_midground1_sampler,		7)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	background0_sampler,	k_ps_emblem_background0_sampler,	8)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	background1_sampler,	k_ps_emblem_background1_sampler,	9)

#endif
