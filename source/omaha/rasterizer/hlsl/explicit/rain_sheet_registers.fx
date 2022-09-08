#if DX_VERSION == 9

// dedicated constants for rain sheets
PIXEL_CONSTANT_EX(float4, movement_and_intervals, 52)
PIXEL_CONSTANT(float4, intensity_and_scale, 53)
PIXEL_CONSTANT_EX(float4, texture_stretch, 54)
PIXEL_CONSTANT_EX(float4, movement0, 55)
PIXEL_CONSTANT_EX(float4, movement1, 56)
PIXEL_CONSTANT_EX(float4, movement2, 57)
PIXEL_CONSTANT_EX(float4, movement3, 58)

BOOL_CONSTANT(vs_arctangent_base, 1)
BOOL_CONSTANT(ps_arctangent_base, 1)

PIXEL_CONSTANT(float4, shadow_proj, 59)
PIXEL_CONSTANT(float4, shadow_depth, 60)

VERTEX_CONSTANT(float4x4, inv_View_Projection, 20)
VERTEX_CONSTANT_EX(float4, sheer_and_attenuation_data, 24)
VERTEX_CONSTANT_EX(float4, movement_and_intervals, 25)
VERTEX_CONSTANT_EX(float4, movement0, 26)
VERTEX_CONSTANT_EX(float4, movement1, 27)
VERTEX_CONSTANT_EX(float4, movement2, 28)
VERTEX_CONSTANT_EX(float4, movement3, 29)
VERTEX_CONSTANT_EX(float4, texture_stretch, 30)

// Noise texture sampled for fog density
sampler tex_noise : register(s0);

// Scene depth texture sampled to fade fog near scene intersections
sampler tex_scene_depth : register(s1);

sampler occlusion_height : register(s2);

#elif DX_VERSION == 11

CBUFFER_BEGIN(RainSheetVS)
	CBUFFER_CONST(RainSheetVS,	float4x4,	inv_View_Projection,			k_vs_rain_sheet_inv_view_projection)
	CBUFFER_CONST(RainSheetVS,	float4, 	sheer_and_attenuation_data, 	k_vs_rain_sheet_sheer_and_attenuation_data)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_movement_and_intervals,		k_vs_rain_sheet_movement_and_intervals)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_movement0,					k_vs_rain_sheet_movement0)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_movement1,					k_vs_rain_sheet_movement1)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_movement2,					k_vs_rain_sheet_movement2)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_movement3,					k_vs_rain_sheet_movement3)
	CBUFFER_CONST(RainSheetVS,	float4, 	vs_texture_stretch,				k_vs_rain_sheet_texture_stretch)
	CBUFFER_CONST(RainSheetVS,	bool, 		vs_arctangent_base,				k_vs_rain_sheet_arctangent_base)
CBUFFER_END

CBUFFER_BEGIN(RainSheetPS)
	CBUFFER_CONST(RainSheetPS,	float4, 	movement_and_intervals,			k_ps_rain_sheet_movement_and_intervals)
	CBUFFER_CONST(RainSheetPS,	float4, 	intensity_and_scale,			k_ps_rain_sheet_intensity_and_scale)
	CBUFFER_CONST(RainSheetPS,	float4, 	texture_stretch,				k_ps_rain_sheet_texture_stretch)
	CBUFFER_CONST(RainSheetPS,	float4, 	movement0,						k_ps_rain_sheet_movement0)
	CBUFFER_CONST(RainSheetPS,	float4, 	movement1,						k_ps_rain_sheet_movement1)
	CBUFFER_CONST(RainSheetPS,	float4, 	movement2,						k_ps_rain_sheet_movement2)
	CBUFFER_CONST(RainSheetPS,	float4, 	movement3,						k_ps_rain_sheet_movement3)
	CBUFFER_CONST(RainSheetPS,	float4, 	shadow_proj,					k_ps_rain_sheet_shadow_proj)
	CBUFFER_CONST(RainSheetPS,	float4, 	shadow_depth,					k_ps_rain_sheet_shadow_depth)
	CBUFFER_CONST(RainSheetPS,	bool,		ps_arctangent_base,				k_ps_rain_sheet_arctangent_base)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	tex_noise,			k_ps_rain_sheet_sampler_tex_noise,			0)
PIXEL_TEXTURE(_2D,				tex_scene_depth, 	k_ps_rain_sheet_sampler_tex_scene_depth,	1)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	occlusion_height, 	k_ps_rain_sheet_sampler_occlusion_height,	2)

#endif
