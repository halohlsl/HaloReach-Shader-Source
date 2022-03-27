#ifndef __HLSL_CONSTANT_GLOBALS_FX
#define __HLSL_CONSTANT_GLOBALS_FX



// ###ctchou $TODO  find more appropriate locations for all these definitions..  some need to be included before all instances of hlsl_constant_global_list.h, but these should be shared with the globals.h file also
		#define k_max_inline_lights				8
		#define k_maximum_simple_light_count	8
		#define k_maximum_node_count			70
// #################


// The following macros will define each constant in HLSL form.
// When compiling the corresponding stage (pixel/vertex), the constant will be assigned a register number
// When the compiling stage doesn't match the constant stage, the constant will not be assigned a register (but will still be declared so we don't have unknown symbol errors)
// Furthermore, we only define constants in the active scopes


	#include "hlsl_registers.fx"
	#include "hlsl_scopes.fx"
		#define	SHADER_CONSTANT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, register_bank, stage, command_buffer_option)		SCOPE_##scope(	hlsl_type, hlsl_name, register_bank##register_start, stage);
			#include "hlsl_constant_global_list.fx"
		#undef SHADER_CONSTANT
	#include "hlsl_scopes_end.fx"
	#undef VERTEX_REGISTER
	#undef PIXEL_REGISTER


#if defined(VERTEX_SHADER)
	#define always_true vs_always_true
#else // PIXEL_SHADER
	#define always_true ps_always_true
#endif // PIXEL_SHADER


// ###ctchou $TODO  find more appropriate locations for all these definitions..   some need to be included before all instances of hlsl_constant_global_list.h:
		#define k_max_inline_lights				8
		#define k_maximum_simple_light_count	8
		#define k_maximum_node_count			70

		#define k_register_node_per_vertex_count		i0
		#define k_register_position_compression_scale 	c12
		#define k_register_position_compression_offset 	c13
		#define k_register_uv_compression_scale_offset 	c14
		#define k_register_node_start					c16
		#define k_node_per_vertex_count					c0

// ###ctchou $TODO move these to a more appropriate location
		#define ILLUM_SCALE			(g_alt_exposure.r)
		#define ILLUM_EXPOSURE		(g_alt_exposure.g)
		#define V_ILLUM_SCALE		(v_alt_exposure.r)
		#define V_ILLUM_EXPOSURE	(v_alt_exposure.g)
		#define k_alpha_test_shader_lighting_constant	c229			// ###ctchou $REMOVE -- this definitely doesn't belong here..  it's a special case constant for leaves...
		#define p_vmf_lighting_constant_0 p_lighting_constant_0
		#define p_vmf_lighting_constant_1 p_lighting_constant_1
		#define p_vmf_lighting_constant_2 p_lighting_constant_2
		#define p_vmf_lighting_constant_3 p_lighting_constant_3

		#if defined(pc)
			#define dynamic_lights_use_array_notation 1
		#endif // pc
// ###########################




// backwards compatibility -- old shaders were relying on these macros being declared for their own use:

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);


	
#endif // __HLSL_CONSTANT_GLOBALS_FX