/*
WATER_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
2/5/2007 7:58:04 PM (xwan)
	Synchanize constant register definition between cpp and fx
*/


// GPU ranges
// vs constants: 130 - 139
// ps constants: 213 - 221
// bool constants: 100 - 104
// samplers: 0 - 1

/* water only*/
VERTEX_CONSTANT(float4, k_vs_water_memexport_addr, 130)
VERTEX_CONSTANT(float4, k_vs_water_index_offset, 131)

PIXEL_CONSTANT(float4, k_ps_water_view_depth_constant, 217)

BOOL_CONSTANT(k_is_lightmap_exist, 100)
BOOL_CONSTANT(k_is_water_interaction, 101)
BOOL_CONSTANT(k_is_water_tessellated, 102)
BOOL_CONSTANT(k_is_camera_underwater, 103)

SAMPLER_CONSTANT(tex_ripple_buffer_slope_height, 1)

/* tesselletion only*/
VERTEX_CONSTANT(float4, k_vs_tess_camera_position, 132)
VERTEX_CONSTANT(float4, k_vs_tess_camera_forward, 133)
VERTEX_CONSTANT(float4, k_vs_tess_camera_diagonal, 134)

/* interaction only*/
VERTEX_CONSTANT(float4, k_vs_ripple_memexport_addr, 130)
VERTEX_CONSTANT(float, k_vs_ripple_pattern_count, 132)
VERTEX_CONSTANT(float, k_vs_ripple_real_frametime_ratio, 133)
VERTEX_CONSTANT(float, k_vs_ripple_particle_index_start, 138)
VERTEX_CONSTANT(float, k_vs_maximum_ripple_particle_number, 139)

BOOL_CONSTANT(k_is_under_screenshot, 104)

SAMPLER_CONSTANT(tex_ripple_pattern, 0)
SAMPLER_CONSTANT(tex_ripple_buffer_height, 1)

/* underwater only */
SAMPLER_CONSTANT(tex_ldr_buffer, 0)
SAMPLER_CONSTANT(tex_depth_buffer, 1)

/* ocean water only */
VERTEX_CONSTANT(float, k_ocean_buffer_radius, 136)
VERTEX_CONSTANT(float4, k_ocean_mesh_constants, 137)
SAMPLER_CONSTANT(tex_ocean_mask, 2)

/* share constants */
VERTEX_CONSTANT(float3, k_vs_camera_position, 131)
VERTEX_CONSTANT(float, k_ripple_buffer_radius, 133)
VERTEX_CONSTANT(float2, k_view_dependent_buffer_center_shifting, 134)
VERTEX_CONSTANT(float4, hidden_from_compiler, 135)

PIXEL_CONSTANT(float4x4, k_ps_water_view_xform_inverse, 213)
PIXEL_CONSTANT(float4, k_ps_water_player_view_constant, 218)
PIXEL_CONSTANT(float4, k_ps_camera_position, 219)
PIXEL_CONSTANT(float, k_ps_underwater_murkiness, 220)
PIXEL_CONSTANT(float3, k_ps_underwater_fog_color, 221)
PIXEL_CONSTANT(float4x4, k_ps_texcoord_to_world_matrix, 224)





