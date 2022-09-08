#if DX_VERSION == 9

sampler rain: register(s0);
sampler2D	tex_scene_depth : register(s1);

PIXEL_CONSTANT(float4, lighting_position_and_cutoff, 112)
PIXEL_CONSTANT(float4, lighting_color_and_falloff_ratio, 113)
PIXEL_CONSTANT(float4, lighting_direction_and_attenuation, 114)
PIXEL_CONSTANT(float4, lighting_falloff_speed_view_direction, 115)
PIXEL_CONSTANT(float4, inverse_z_transform, 116)

VERTEX_CONSTANT(float4, movement_and_intensity, 200)
VERTEX_CONSTANT(float4x3, rotation, 201)
VERTEX_CONSTANT(float3, project_texture_cooridnate0, 204)
VERTEX_CONSTANT(float3, project_texture_cooridnate1, 205)

#elif DX_VERSION == 11

CBUFFER_BEGIN(RainLightVolumeVS)
	CBUFFER_CONST(RainLightVolumeVS,	float4, 	movement_and_intensity,					k_vs_rain_light_volume_movement_and_intensity)
	CBUFFER_CONST(RainLightVolumeVS,	float4x3, 	rotation, 								k_vs_rain_light_volume_rotation)
	CBUFFER_CONST(RainLightVolumeVS,	float3, 	project_texture_cooridnate0, 			k_vs_rain_light_volume_project_texture_coordinate0)
	CBUFFER_CONST(RainLightVolumeVS,	float3, 	project_texture_cooridnate1, 			k_vs_rain_light_volume_project_texture_coordinate1)
CBUFFER_END

CBUFFER_BEGIN(RainLightVolumePS)
	CBUFFER_CONST(RainLightVolumePS,	float4,		lighting_position_and_cutoff,			k_ps_rain_light_volume_lighting_position_and_cutoff)
	CBUFFER_CONST(RainLightVolumePS,	float4,		lighting_color_and_falloff_ratio,		k_ps_rain_light_volume_lighting_color_and_falloff_ratio)
	CBUFFER_CONST(RainLightVolumePS,	float4,		lighting_direction_and_attenuation,		k_ps_rain_light_volume_lighting_direction_and_attenuation)
	CBUFFER_CONST(RainLightVolumePS,	float4,		lighting_falloff_speed_view_direction,	k_ps_rain_light_volume_lighting_falloff_speed_view_direction)
	CBUFFER_CONST(RainLightVolumePS,	float4,		inverse_z_transform,					k_ps_rain_light_volume_inverse_z_transform)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	rain,				k_ps_rain_light_volume_rain_sampler, 0)
PIXEL_TEXTURE(_2D,				tex_scene_depth,	k_ps_rain_light_volume_tex_scene_depth_sampler, 1)

#endif
