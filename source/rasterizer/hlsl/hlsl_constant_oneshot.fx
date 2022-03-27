#ifndef _HLSL_CONSTANT_ONESHOT_FX_
#define _HLSL_CONSTANT_ONESHOT_FX_
/*
//NOTE: if you modify any of this, than you need to modify hlsl_constant_oneshot.h 

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif

// Shader constants which are fair game (set prior to each draw call which uses them)
#define k_register_node_per_vertex_count		i0
#define k_register_position_compression_scale 	c12
#define k_register_position_compression_offset 	c13
#define k_register_uv_compression_scale_offset 	c14
#define k_register_node_start					c16
#define k_node_per_vertex_count					c0

#define k_alpha_test_shader_lighting_constant	c229

VERTEX_CONSTANT(float4, Position_Compression_Scale, k_register_position_compression_scale);
VERTEX_CONSTANT(float4, Position_Compression_Offset, k_register_position_compression_offset);
VERTEX_CONSTANT(float4, UV_Compression_Scale_Offset, k_register_uv_compression_scale_offset);

#ifndef IGNORE_SKINNING_NODES
VERTEX_CONSTANT(int, Node_Per_Vertex_Count, k_node_per_vertex_count); 
VERTEX_CONSTANT(float4, Nodes[70][3], k_register_node_start); // !!!Actually uses c16-c227 because we own multiples of 4
VERTEX_CONSTANT(float4, Nodes_pad0, c226);
VERTEX_CONSTANT(float4, Nodes_pad1, c227);
#endif // IGNORE_SKINNING_NODES


VERTEX_CONSTANT(float4, k_vs_hidden_from_compiler, c250); 
VERTEX_CONSTANT(float4, k_vs_tessellation_parameter, c251);  // store memexport address in pre-pass, store tess param in post_pass


PIXEL_CONSTANT( float4, k_ps_analytical_light_direction, c11);
PIXEL_CONSTANT( float4, k_ps_constant_shadow_alpha, c11);			// overlaps with k_ps_analytical_light_direction, but they aren't used at the same time
PIXEL_CONSTANT( float4, k_ps_analytical_light_intensity, c13);

#ifndef pc
PIXEL_CONSTANT( float4, k_ps_bounce_light_direction, c51);
PIXEL_CONSTANT( float4, k_ps_bounce_light_intensity, c52);
#endif //!pc


#ifndef pc
PIXEL_CONSTANT( float4, k_ps_imposter_changing_color_0, c53);
PIXEL_CONSTANT( float4, k_ps_imposter_changing_color_1, c54);
#endif //!pc

PIXEL_CONSTANT(bool, dynamic_light_shadowing, b13);

// Active camo constants

// set immediately before rendering
PIXEL_CONSTANT(float4, k_ps_active_camo_factor, c221);
// set at the start of render_transparents
PIXEL_CONSTANT(float4, k_ps_distort_bounds, c220);
*/
#endif //ifndef _HLSL_CONSTANT_ONESHOT_FX_
