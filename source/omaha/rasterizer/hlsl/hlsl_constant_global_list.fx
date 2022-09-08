// This file contains a list of GLOBAL shader constants.
//
// Global shader constants are constants that are NOT updated with each render call,
// and therefore must not be overwritten by other shaders within the same active scopes.
// (See hlsl_scopes.fx for a description of the global scopes and when they are active)
//
// To do this, in every shader we declare all constants for the shader's scope.
// This makes sure that no automatically assigned constants will be aliased to an active global constants
//
// We can still have aliasing by directly assigning a constant to a register -- the shader author is responsible for solving such conflicts
// (###ctchou $TODO we can do automatic testing at shader compile time to prevent this)
//
//

#if DX_VERSION == 9

#include "hlsl_constant_declaration_defaults.fx"

// type			hlsl type	hlsl name								code name				register start	count		scope
VERTEX_FLOAT(	float4x4,	View_Projection,						k_register_viewproj_xform,			0,		4,		global_render, command_buffer_cache_never)		// WARNING:  View_Projection[0] is _NOT_ the same as k_register_viewproj_xform, HLSL treats the matrix as transposed

VERTEX_FLOAT(	float4x4,	Camera_To_World,						k_camera_to_world_xform,			4,		4,		global_render, command_buffer_cache_never)		// Camera To World matrix, aliased to camera vectors below
VERTEX_FLOAT(	float3,		Camera_Right,							k_camera_right,						4,		1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float3,		Camera_Up,								k_camera_up,						5,		1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float3,		Camera_Backward,						k_camera_backward,					6,		1,		global_render, command_buffer_cache_never)		// the position and orientation of the camera in world space
VERTEX_FLOAT(	float3,		Camera_Position,						k_camera_position,					7,		1,		global_render, command_buffer_cache_never)

VERTEX_FLOAT_FREE_FOR_SHADERS(																			8,		11)							// ###ctchou $TODO can we declare free constants in a way to allow shaders to just grab one?

VERTEX_FLOAT(	float4,		Position_Compression_Scale,				k_position_compression_scale,		12,		1,		mesh_default, command_buffer_cache_all)
VERTEX_FLOAT(	float4,		Position_Compression_Offset,			k_position_compression_offset,		13,		1,		mesh_default, command_buffer_cache_all)
VERTEX_FLOAT(	float4,		UV_Compression_Scale_Offset,			k_uv_compression_scale_offset,		14,		1,		mesh_default, command_buffer_cache_all)

VERTEX_FLOAT(	float4,		Nodes[70][3],							k_node_start,						16,		70*3,	mesh_skinning, command_buffer_cache_never)		// !!!Actually uses c16-c227 because we own multiples of 4
VERTEX_FLOAT(	float4,		Nodes_pad0,								k_node_padding0,					226,	1,		mesh_skinning, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		Nodes_pad1,								k_node_padding2,					227,	1,		mesh_skinning, command_buffer_cache_never)

VERTEX_FLOAT(	float4,		v_exposure,								k_vs_exposure,						229,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_alt_exposure,							k_vs_alt_exposure,					230,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT_FREE_FOR_SHADERS(																			231,	231)

VERTEX_FLOAT(	float4,		v_atmosphere_constant_0,				k_vs_atmosphere_constant_0,			232,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_1,				k_vs_atmosphere_constant_1,			233,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_2,				k_vs_atmosphere_constant_2,			234,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_3,				k_vs_atmosphere_constant_3,			235,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_4,				k_vs_atmosphere_constant_4,			236,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_5,				k_vs_atmosphere_constant_5,			237,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_atmosphere_constant_6,				k_vs_atmosphere_constant_6,			238,	1,		transparents, command_buffer_cache_never)
VERTEX_FLOAT_FREE_FOR_SHADERS(																			239,	239)

VERTEX_FLOAT(	float4,		k_vs_active_camo_factor,				k_vs_active_camo_factor,			240,	1,		mesh_default, command_buffer_cache_never)		// could reduce scope, only used for active-camo apply..  which doesn't need lighting info
VERTEX_FLOAT(	float4x4,	Shadow_Projection,						k_vs_shadow_projection,				240,	4,		global_render, command_buffer_cache_never)		// used for dynamic light, to hold the light projection matrix
VERTEX_FLOAT(	float4,		v_lighting_constant_0,					k_vs_lighting_constant_0,			240,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_lighting_constant_1,					k_vs_lighting_constant_1,			241,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_lighting_constant_2,					k_vs_lighting_constant_2,			242,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_lighting_constant_3,					k_vs_lighting_constant_3,			243,	1,		global_render, command_buffer_cache_never)

VERTEX_FLOAT(	float4,		v_analytical_light_direction,			k_vs_analytical_light_direction,	244,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		v_analytical_light_intensity,			k_vs_analytical_light_intensity,	245,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		k_vs_wetness_constants,					k_vs_wetness_constants,				246,	1,		global_render, command_buffer_cache_never)		// x: width of wetness texture; y: offset of wetness texture; z: unused; w: probe wetness (notice, if -1 means no valid wetness texture)
VERTEX_FLOAT(	float4,		per_vertex_lighting_offset,				k_per_vertex_lighting_offset,		247,	1,		global_render, command_buffer_cache_never)

VERTEX_FLOAT(	float4,		k_vs_hidden_from_compiler,				k_vs_hidden_from_compiler,			248,	1,		mesh_default, command_buffer_cache_unknown)
VERTEX_FLOAT(	float4,		k_vs_tessellation_parameter,			k_vs_tessellation_parameter,		249,	1,		mesh_default, command_buffer_cache_never)		// store memexport address in pre-pass, store tess param in post_pass
VERTEX_FLOAT(	float4,		k_vs_planar_fog_constant_0,				k_vs_planar_fog_constant_0,			250,	1,		global_render, command_buffer_cache_never)
VERTEX_FLOAT(	float4,		k_vs_planar_fog_constant_1,				k_vs_planar_fog_constant_1,			251,	1,		global_render, command_buffer_cache_never)

VERTEX_FLOAT_FREE_FOR_SHADERS(																			252,	255)

VERTEX_INT(		int,		Node_Per_Vertex_Count,					k_node_per_vertex_count,			0,		1,		mesh_skinning, command_buffer_cache_all)


//				hlsl type	hlsl name								code name				register start	count		scope
PIXEL_FLOAT(	float4,		g_exposure,								k_ps_exposure,						0,		1,		global_render, command_buffer_cache_never)		// exposure multiplier, HDR target multiplier, HDR alpha multiplier, LDR alpha multiplier		// ###ctchou $REVIEW could move HDR target multiplier to exponent bias and just set HDR alpha multiplier..
PIXEL_FLOAT(	float4,		p_lighting_constant_0,					k_ps_lighting_constant_0,			1,		1,		global_render, command_buffer_cache_never)		// NOTE: these are also used for shadow_apply entry point (to hold the shadow projection matrix), as well as dynamic lights (to hold additional shadow info)
PIXEL_FLOAT(	float4,		Shadow_Projection_z,					k_ps_shadow_projection_z,			1,		1,		global_render, command_buffer_cache_never)		//
PIXEL_FLOAT(	float4,		p_lighting_constant_1,					k_ps_lighting_constant_1,			2,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_2,					k_ps_lighting_constant_2,			3,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_3,					k_ps_lighting_constant_3,			4,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_4,					k_ps_lighting_constant_4,			5,		1,		global_render, command_buffer_cache_never)		// these are not used anymore, but they are overlapping and assumed to be reserved by alot of other shaders so it's not simple to deallocate them
PIXEL_FLOAT(	float4,		p_dynamic_light_gel_xform,				k_ps_gel_transform_0,				5,		1,		global_render, command_buffer_cache_never)		// overlaps lighting constant - they're unused in the expensive dynamic light pass
PIXEL_FLOAT(	float4,		p_lighting_constant_5,					k_ps_lighting_constant_5,			6,		1,		global_render, command_buffer_cache_never)		//
PIXEL_FLOAT(	float4,		p_lighting_constant_6,					k_ps_lighting_constant_6,			7,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_7,					k_ps_lighting_constant_7,			8,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_8,					k_ps_lighting_constant_8,			9,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		p_lighting_constant_9,					k_ps_lighting_constant_9,			10,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		k_ps_active_camo_factor,				k_ps_active_camo_factor,			10,		1,		mesh_default, command_buffer_cache_never)		// only used for active-camo apply..  which doesn't need lighting info
PIXEL_FLOAT(	float4,		p_shadow_dir,							k_ps_shadow_dir,					10,		1,		global_render, command_buffer_cache_never)		// ###ctchou $TODO verify scope (was lighting)

PIXEL_FLOAT(	float4,		g_alt_exposure,							k_ps_alt_exposure,					11,		1,		global_render, command_buffer_cache_never)		// self-illum exposure, unused, unused, unused

PIXEL_FLOAT(	float4,		k_ps_analytical_light_direction,		k_ps_analytical_light_direction,	12,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		k_ps_constant_shadow_alpha,				k_ps_shadow_alpha,					12,		1,		mesh_default, command_buffer_cache_never)		// ###ctchou $TODO verify scope -- overlaps with k_ps_analytical_light_direction, but they aren't used at the same time
PIXEL_FLOAT(	float4,		k_ps_analytical_light_intensity,		k_ps_analytical_light_intensity,	13,		1,		global_render, command_buffer_cache_never)

PIXEL_FLOAT(	float2,		texture_size,							k_ps_texture_size,					14,		1,		global_render, command_buffer_cache_never)		// used for pixel-shader implemented bilinear, and albedo textures
PIXEL_FLOAT(	float4,		dynamic_environment_blend,				k_ps_dynamic_environment_blend,		15,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float3,		Camera_Position_PS,						k_camera_position_ps,				16,		1,		global_render, command_buffer_cache_never)

PC_PIXEL_FLOAT(	float,		simple_light_count,						k_register_simple_light_count,		17,		1,		global_render, command_buffer_cache_never)

PC_PIXEL_FLOAT(	float4,		simple_lights[k_max_inline_lights][5],	k_register_simple_light_start_pc,	18,		k_max_inline_lights * 5,	global_render, command_buffer_cache_never)
XE_PIXEL_FLOAT(	float4,		simple_lights[k_max_inline_lights*5],	k_register_simple_light_start,		18,		k_max_inline_lights * 5,	global_render, command_buffer_cache_never)

XE_PIXEL_FLOAT( float4,		k_ps_bounce_light_direction,			k_ps_bounce_light_direction,		58,		1,		global_render, command_buffer_cache_never)
XE_PIXEL_FLOAT( float4,		k_ps_bounce_light_intensity,			k_ps_bounce_light_intensity,		59,		1,		global_render, command_buffer_cache_never)
XE_PIXEL_FLOAT( float4,		k_ps_imposter_changing_color_0,			k_ps_imposter_changing_color_0,		60,		1,		mesh_default, command_buffer_cache_never)
XE_PIXEL_FLOAT( float4,		k_ps_imposter_changing_color_1,			k_ps_imposter_changing_color_1,		61,		1,		mesh_default, command_buffer_cache_never)
XE_PIXEL_FLOAT( float4,		k_ps_imposter_changing_color_2,			k_ps_imposter_changing_color_2,		62,		1,		mesh_default, command_buffer_cache_never)
XE_PIXEL_FLOAT( float4,		k_ps_imposter_changing_color_3,			k_ps_imposter_changing_color_3,		63,		1,		mesh_default, command_buffer_cache_never)


PIXEL_FLOAT(	float4,		p_render_debug_mode,					k_ps_render_debug_mode,				64,		1,		global_render, command_buffer_cache_never)
PC_PIXEL_FLOAT(	float,		p_shader_pc_specular_enabled,			k_shader_pc_specular_enabled,		65,		1,		global_render, command_buffer_cache_never)		// first register after simple lights

PC_PIXEL_FLOAT(	float,		p_shader_pc_albedo_lighting,			k_shader_pc_albedo_lighting,		66,		1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		k_ps_rain_ripple_coefficients,			k_ps_rain_ripple_coefficients,		67,		1,		global_render, command_buffer_cache_never)		// tex_scale, size_with_margin, splash_reflection_intensify, display_speed

PIXEL_FLOAT(	float4,		k_ps_wetness_coefficients,				k_ps_wetness_coefficients,			68,		1,		global_render, command_buffer_cache_never)		// wetness, game_time(second), cubemap blending, rain intensity
PIXEL_FLOAT(	float4,		p_analytical_gel_xform[3],				k_ps_analytical_light_xform,		69,		3,		global_render, command_buffer_cache_never)

#define p_tiling_vpos_offset float2(0,0)

PIXEL_FLOAT(	float4,		antialias_scalars,						k_antialias_scalars,				72,	1,		global_render, command_buffer_cache_never)		//
PIXEL_FLOAT(	float4,		object_velocity,						k_object_velocity,					73,	1,		global_render, command_buffer_cache_never)		// velocity of the current object, world space per object (approx)	###ctchou $TODO we could compute this in the vertex shader as a function of the bones...

PIXEL_FLOAT(	float4,		p_lightmap_compress_constant_0,			k_ps_lightmap_compress_constant_0,	74,	1,		global_render, command_buffer_cache_never)
PIXEL_FLOAT(	float4,		depth_constants,						k_ps_depth_constants,				75,	1,		global_render, command_buffer_cache_never)

PIXEL_FLOAT(	float4,		k_ps_command_buffer_last_persistant,	k_ps_command_buffer_last_persistant,76,	1,		global_render, command_buffer_cache_never)

PIXEL_FLOAT(	float,		k_ps_effects_shared_constants,			k_ps_effects_shared_constants,		77,	4,		global_render, command_buffer_cache_never)

//---------------------

XE_PIXEL_INT(	int,		simple_light_count,						k_simple_light_count_int,			0,		1,		global_render, command_buffer_cache_never)

//---------------------

PIXEL_BOOL(		bool,		ps_always_true,							k_ps_always_true,					0,		1,		global_render, command_buffer_cache_never)
VERTEX_BOOL(	bool,		vs_always_true,							k_vs_always_true,					0,		1,		global_render, command_buffer_cache_never)
PIXEL_BOOL(		bool,		k_ps_bool_is_uber_light_directional,	k_ps_bool_is_uber_light_directional,1,		1,		lighting, command_buffer_cache_never)
PIXEL_BOOL(		bool,		dynamic_light_shadowing,				k_ps_bool_dynamic_light_shadowing,	13,		1,		mesh_default, command_buffer_cache_never)
PIXEL_BOOL(		bool,		ps_boolean_enable_wet_effect,			k_ps_boolean_enable_wet_effect,		121,	1,		global_render, command_buffer_cache_never)
VERTEX_BOOL(	bool,		vs_boolean_enable_wet_effect,			k_vs_boolean_enable_wet_effect,		121,	1,		global_render, command_buffer_cache_never)

//---------------------

PIXEL_BOOL(		bool,		no_dynamic_lights,						k_no_dynamic_lights,				6,		1,		global_render, command_buffer_cache_always)
XE_PIXEL_BOOL(	bool,		k_boolean_enable_imposter_capture,		k_boolean_enable_imposter_capture,	122,	1,		global_render, command_buffer_cache_never)

//---------------------

PIXEL_SAMPLER(		sampler,	scene_ldr_texture,					k_sampler_scene_ldr_texture,		10,		1,		global_render, command_buffer_cache_unknown)		// WATER, ACTIVE CAMO
PIXEL_SAMPLER(		sampler,	depth_buffer,						k_sampler_depth_buffer,				11,		1,		global_render, command_buffer_cache_unknown)		// WATER, PARTICLES, TRANSPARENTS


PIXEL_SAMPLER(		sampler,	analytical_gel,						k_sampler_analytical_gel,			9,		1,		lighting, command_buffer_cache_unknown)
PIXEL_SAMPLER(		sampler,	albedo_texture,						k_sampler_albedo_texture,			10,		1,		lighting_opaque, command_buffer_cache_unknown)
PIXEL_SAMPLER(		sampler,	normal_texture,						k_sampler_normal_texture,			11,		1,		lighting_opaque, command_buffer_cache_unknown)

XE_PIXEL_SAMPLER(	sampler,	lightprobe_dir_and_bandwidth_ps,	k_sampler_lightmap_dir_and_bandwidth_ps,	13,		1,		lighting, command_buffer_cache_unknown)
XE_PIXEL_SAMPLER(	sampler,	lightprobe_hdr_color_ps,			k_sampler_lightmap_hdr_color_ps,	14,		1,		lighting, command_buffer_cache_unknown)

XE_PIXEL_SAMPLER(	sampler,	shadow_mask_texture,				k_sampler_shadow_mask,				15,		1,		lighting_opaque, command_buffer_cache_unknown)

XE_PIXEL_SAMPLER(	sampler,	dynamic_environment_map_0,			k_ps_sampler_environment_map_0,		16,		1,		lighting, command_buffer_cache_unknown)			// _static lighting pass only
XE_PIXEL_SAMPLER(	sampler,	dynamic_environment_map_1,			k_ps_sampler_environment_map_1,		17,		1,		lighting, command_buffer_cache_unknown)
XE_PIXEL_SAMPLER(	sampler,	k_ps_sampler_wet_rain_ripple,		k_ps_sampler_wet_rain_ripple,		18,		1,		wetness, command_buffer_cache_unknown)


// alias wetness/fog into same sampler
XE_VERTEX_SAMPLER(	sampler,	k_vs_sampler_per_vertex_wetness,	k_vs_sampler_per_vertex_wetness,	2,		1,		wetness, command_buffer_cache_unknown)			// _static lighting only
XE_VERTEX_SAMPLER(	sampler,	k_vs_sampler_atm_fog_table,		k_vs_sampler_atm_fog_table,	2,		1,		global_render, command_buffer_cache_unknown)

XE_VERTEX_BOOL(bool,		k_vs_boolean_enable_atm_fog,		k_vs_boolean_enable_atm_fog,	7,	1,		global_render, command_buffer_cache_never)
XE_VERTEX_BOOL(bool,		k_bool_render_rigid_imposter,		k_bool_render_rigid_imposter,	24,	1,		global_render, command_buffer_cache_unknown)

#include "hlsl_constant_declaration_defaults_end.fx"

#elif DX_VERSION == 11

#ifndef DEFINE_CPP_CONSTANTS
#include "global.fx"
#define always_true true
#define no_dynamic_lights false // never set in code?
#endif

CBUFFER_BEGIN(ViewVS)
	CBUFFER_CONST(ViewVS,		float4x4,			View_Projection,				k_register_viewproj_xform)
	CBUFFER_CONST(ViewVS,		float4x4,			Camera_To_World,				k_camera_to_world_xform)
	CBUFFER_CONST(ViewVS,		float4,				v_clip_plane,					k_vs_clip_plane)
CBUFFER_END

SHADER_CONST_ALIAS(ViewVS,		float3,				Camera_Right,					Camera_To_World._m00_m10_m20,			k_camera_right,			k_camera_to_world_xform,	0)
SHADER_CONST_ALIAS(ViewVS,		float3,				Camera_Up,						Camera_To_World._m01_m11_m21,			k_camera_up,			k_camera_to_world_xform,	16)
SHADER_CONST_ALIAS(ViewVS,		float3,				Camera_Backward,				Camera_To_World._m02_m12_m22,			k_camera_backward,		k_camera_to_world_xform,	32)
SHADER_CONST_ALIAS(ViewVS,		float3,				Camera_Position,				Camera_To_World._m03_m13_m23,			k_camera_position,		k_camera_to_world_xform,	48)

CBUFFER_BEGIN_FIXED(VertexCompressionVS, 11)
	CBUFFER_CONST(VertexCompressionVS,		float4,		Position_Compression_Scale,		k_position_compression_scale)
	CBUFFER_CONST(VertexCompressionVS,		float4,		Position_Compression_Offset,	k_position_compression_offset)
	CBUFFER_CONST(VertexCompressionVS,		float4,		UV_Compression_Scale_Offset,	k_uv_compression_scale_offset)
CBUFFER_END

CBUFFER_BEGIN_FIXED(SkinningVS, 12)
	CBUFFER_CONST_ARRAY(SkinningVS,			float4,		Nodes, [70][3],					k_node_start)
CBUFFER_END

CBUFFER_BEGIN(ExposureVS)
	CBUFFER_CONST(ExposureVS,	float4,		v_exposure,					k_vs_exposure)
	CBUFFER_CONST(ExposureVS,	float4,		v_alt_exposure,				k_vs_alt_exposure)
CBUFFER_END

CBUFFER_BEGIN(ActiveCamoVS)
	CBUFFER_CONST(ActiveCamoVS,	float4,		k_vs_active_camo_factor,		k_vs_active_camo_factor)
CBUFFER_END

CBUFFER_BEGIN(LightingVS)
	CBUFFER_CONST(LightingVS,	float4,		v_lighting_constant_0,			k_vs_lighting_constant_0)
	CBUFFER_CONST(LightingVS,	float4,		v_lighting_constant_1,			k_vs_lighting_constant_1)
	CBUFFER_CONST(LightingVS,	float4,		v_lighting_constant_2,			k_vs_lighting_constant_2)
	CBUFFER_CONST(LightingVS,	float4,		v_lighting_constant_3,			k_vs_lighting_constant_3)
CBUFFER_END

#define _VS_SHADOW_PROJECTION_VALUE transpose(float4x4(v_lighting_constant_0, v_lighting_constant_1, v_lighting_constant_2, v_lighting_constant_3))
SHADER_CONST_ALIAS(LightingVS,	float4x4,	Shadow_Projection,				_VS_SHADOW_PROJECTION_VALUE,			k_vs_shadow_projection,				k_vs_lighting_constant_0,		0)

CBUFFER_BEGIN(FogVS)
	CBUFFER_CONST(FogVS,		float4,		k_vs_planar_fog_constant_0,		k_vs_planar_fog_constant_0)
	CBUFFER_CONST(FogVS,		float4,		k_vs_planar_fog_constant_1,		k_vs_planar_fog_constant_1)
CBUFFER_END

CBUFFER_BEGIN(MeshVS)
	CBUFFER_CONST(MeshVS,		float4,		k_vs_hidden_from_compiler,		k_vs_hidden_from_compiler)
	CBUFFER_CONST(MeshVS,		float4,		k_vs_tessellation_parameter,	k_vs_tessellation_parameter)
	CBUFFER_CONST(MeshVS,		float4,		v_analytical_light_direction,	k_vs_analytical_light_direction)
	CBUFFER_CONST(MeshVS,		float4,		v_analytical_light_intensity,	k_vs_analytical_light_intensity)
	CBUFFER_CONST(MeshVS,		float4,		k_vs_wetness_constants,			k_vs_wetness_constants)
	CBUFFER_CONST(MeshVS,		float4,		per_vertex_lighting_offset,		k_per_vertex_lighting_offset)
	CBUFFER_CONST(MeshVS,		bool,		vs_boolean_enable_wet_effect,	k_vs_boolean_enable_wet_effect)
	CBUFFER_CONST(MeshVS,		bool,		k_vs_boolean_enable_atm_fog,	k_vs_boolean_enable_atm_fog)
	CBUFFER_CONST(MeshVS,		bool,		k_bool_render_rigid_imposter,	k_bool_render_rigid_imposter)
CBUFFER_END

CBUFFER_BEGIN(ViewPS)
	CBUFFER_CONST(ViewPS,		float3,		Camera_Position_PS,				k_camera_position_ps)
	CBUFFER_CONST(ViewPS,		float,		Camera_Position_PS_pad,			k_camera_position_ps_pad)
	CBUFFER_CONST(ViewPS,		float4,		depth_constants,				k_ps_depth_constants)
	CBUFFER_CONST(ViewPS,		bool,		shadow_mask_enabled,			k_ps_shadow_mask_enabled)
CBUFFER_END

CBUFFER_BEGIN(ExposurePS)
	CBUFFER_CONST(ExposurePS,	float4,		g_exposure,						k_ps_exposure)
	CBUFFER_CONST(ExposurePS,	float4,		g_alt_exposure,					k_ps_alt_exposure)
CBUFFER_END

CBUFFER_BEGIN(LightingPS)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_0,				k_ps_lighting_constant_0)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_1,				k_ps_lighting_constant_1)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_2,				k_ps_lighting_constant_2)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_3,				k_ps_lighting_constant_3)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_4,				k_ps_lighting_constant_4)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_5,				k_ps_lighting_constant_5)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_6,				k_ps_lighting_constant_6)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_7,				k_ps_lighting_constant_7)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_8,				k_ps_lighting_constant_8)
	CBUFFER_CONST(LightingPS,	float4,		p_lighting_constant_9,				k_ps_lighting_constant_9)
	CBUFFER_CONST(LightingPS,	float4,		shadow_pixel_size,					k_ps_shadow_pixel_size)
	CBUFFER_CONST(LightingPS,	bool,		dynamic_light_shadowing,			k_ps_bool_dynamic_light_shadowing)
	CBUFFER_CONST(LightingPS, 	bool,		k_boolean_enable_imposter_capture,	k_boolean_enable_imposter_capture)
CBUFFER_END

SHADER_CONST_ALIAS(LightingPS,	float4,		Shadow_Projection_z,			p_lighting_constant_0,			k_ps_shadow_projection_z,		k_ps_lighting_constant_0,	0)
SHADER_CONST_ALIAS(LightingPS,	float4,		p_dynamic_light_gel_xform,		p_lighting_constant_4,			k_ps_gel_transform_0,			k_ps_lighting_constant_4,	0)
SHADER_CONST_ALIAS(LightingPS,	float4,		k_ps_active_camo_factor,		p_lighting_constant_9,			k_ps_active_camo_factor,		k_ps_lighting_constant_9,	0)
SHADER_CONST_ALIAS(LightingPS,	float4,		p_shadow_dir,					p_lighting_constant_9,			k_ps_shadow_dir,				k_ps_lighting_constant_9,	0)

CBUFFER_BEGIN(MeshPS)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_analytical_light_direction,		k_ps_analytical_light_direction)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_analytical_light_intensity,		k_ps_analytical_light_intensity)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_constant_shadow_alpha,				k_ps_shadow_alpha)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_bounce_light_direction,			k_ps_bounce_light_direction)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_bounce_light_intensity,			k_ps_bounce_light_intensity)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_wetness_coefficients,				k_ps_wetness_coefficients)
	CBUFFER_CONST(MeshPS,		float4,		k_ps_rain_ripple_coefficients,			k_ps_rain_ripple_coefficients)
	CBUFFER_CONST_ARRAY(MeshPS,	float4,		p_analytical_gel_xform, [3],			k_ps_analytical_light_xform)
	CBUFFER_CONST(MeshPS,		float4,		antialias_scalars,						k_antialias_scalars)
	CBUFFER_CONST(MeshPS,		float4,		object_velocity,						k_object_velocity)
	CBUFFER_CONST(MeshPS,		float4,		p_lightmap_compress_constant_0,			k_ps_lightmap_compress_constant_0)
	CBUFFER_CONST(MeshPS, 		bool,		k_ps_bool_is_uber_light_directional,	k_ps_bool_is_uber_light_directional)
	CBUFFER_CONST(MeshPS,		bool,		ps_boolean_enable_wet_effect,			k_ps_boolean_enable_wet_effect)
CBUFFER_END

CBUFFER_BEGIN(MiscPS)
	CBUFFER_CONST(MiscPS,	float2,		texture_size,						k_ps_texture_size)
	CBUFFER_CONST(MiscPS,	float2,		texture_size_pad,					k_ps_texture_size_pad)
	CBUFFER_CONST(MiscPS,	float4,		dynamic_environment_blend,			k_ps_dynamic_environment_blend)
	CBUFFER_CONST(MiscPS,	float4,		p_render_debug_mode,				k_ps_render_debug_mode)
	CBUFFER_CONST(MiscPS,	float,		p_shader_pc_specular_enabled,		k_shader_pc_specular_enabled)
	CBUFFER_CONST(MiscPS,	float3,		p_shader_pc_specular_enabled_pad,	k_shader_pc_specular_enabled_pad)
	CBUFFER_CONST(MiscPS,	float,		p_shader_pc_albedo_lighting,		k_shader_pc_albedo_lighting)
	CBUFFER_CONST(MiscPS,	float3,		p_shader_pc_albedo_lighting_pad,	k_shader_pc_albedo_lighting_pad)
CBUFFER_END

CBUFFER_BEGIN(SimpleLightsPS)
	CBUFFER_CONST(SimpleLightsPS,		uint,		simple_light_count,									k_ps_simple_light_count_int)
	CBUFFER_CONST(SimpleLightsPS,		uint3,		simple_light_count_pad,								k_register_simple_light_count_pad)
	CBUFFER_CONST_ARRAY(SimpleLightsPS,	float4,		simple_lights, [k_max_inline_lights][5],			k_register_simple_light_start)
CBUFFER_END

CBUFFER_BEGIN(ImposterPS)
	CBUFFER_CONST(ImposterPS,			float4,		k_ps_imposter_changing_color_0,			k_ps_imposter_changing_color_0)
	CBUFFER_CONST(ImposterPS,			float4,		k_ps_imposter_changing_color_1,			k_ps_imposter_changing_color_1)
	CBUFFER_CONST(ImposterPS,			float4,		k_ps_imposter_changing_color_2,			k_ps_imposter_changing_color_2)
	CBUFFER_CONST(ImposterPS,			float4,		k_ps_imposter_changing_color_3,			k_ps_imposter_changing_color_3)
CBUFFER_END

PIXEL_SAMPLER(clamp_trilinear_sampler,	k_ps_clamp_trilinear_sampler,	15)
PIXEL_SAMPLER(lightmap_sampler, k_ps_lightmap_sampler, 14)
PIXEL_TEXTURE_AND_SAMPLER(_2D,			analytical_gel,						k_sampler_analytical_gel,					13)
PIXEL_TEXTURE_USING_SAMPLER(_3D,		k_ps_sampler_wet_rain_ripple,		k_ps_sampler_wet_rain_ripple,				14,		clamp_trilinear_sampler)
PIXEL_TEXTURE_USING_SAMPLER(_2D,		scene_ldr_texture,					k_sampler_scene_ldr_texture,				15,		clamp_trilinear_sampler)

PIXEL_TEXTURE(_2D,		albedo_texture,						k_sampler_albedo_texture,					16)
PIXEL_TEXTURE(_2D,		normal_texture,						k_sampler_normal_texture,					17)
PIXEL_TEXTURE(_2D,		depth_buffer,						k_sampler_depth_buffer,						18)
PIXEL_TEXTURE(_2D,		shadow_mask_texture,				k_sampler_shadow_mask,						19)
PIXEL_TEXTURE_USING_SAMPLER(_CUBE,		dynamic_environment_map_0,			k_ps_sampler_environment_map_0,				20,		clamp_trilinear_sampler)
PIXEL_TEXTURE_USING_SAMPLER(_CUBE,		dynamic_environment_map_1,			k_ps_sampler_environment_map_1,				21,		clamp_trilinear_sampler)
PIXEL_TEXTURE_USING_SAMPLER(_2D,		lightprobe_dir_and_bandwidth_ps,	k_sampler_lightmap_dir_and_bandwidth_ps,	22,		lightmap_sampler)
PIXEL_TEXTURE_USING_SAMPLER(_2D_ARRAY,	lightprobe_hdr_color_ps,			k_sampler_lightmap_hdr_color_ps,			23,		lightmap_sampler)

// alias wetness/fog into same sampler
VERTEX_TEXTURE_AND_SAMPLER(_2D,		k_vs_sampler_per_vertex_wetness,	k_vs_sampler_per_vertex_wetness,	4)
VERTEX_TEXTURE_AND_SAMPLER(_2D,		k_vs_sampler_atm_fog_table,			k_vs_sampler_atm_fog_table,			5)

BYTE_ADDRESS_BUFFER(per_vertex_lightprobe_buffer, k_vs_per_vertex_lightprobe_buffer, 17)

#endif

