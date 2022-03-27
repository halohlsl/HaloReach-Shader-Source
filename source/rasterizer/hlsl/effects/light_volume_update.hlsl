/*
LIGHT_VOLUME_UPDATE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for light_volume physics, state updates
*/

#ifdef VERTEX_SHADER
    // this is updated during transparent section
	#define SCOPE_TRANSPARENTS
#endif

#include "hlsl_constant_globals.fx"

#ifdef VERTEX_SHADER

#define MEMEXPORT_ENABLED 1

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);

#include "hlsl_vertex_types.fx"
#include "effects\light_volume_common.fx"

//This comment causes the shader compiler to be invoked for certain types
//@generate light_volume

typedef s_light_volume_vertex s_profile_in;
typedef void s_profile_out;

#ifndef pc

s_profile_out light_volume_main( s_profile_in IN )
{
	s_profile_state STATE;
	s_profile_out OUT;

	int buffer_index= profile_index_to_buffer_index(IN.index);
	//STATE= read_profile_state(buffer_index);	// Light volumes are stateless

	STATE.m_percentile= IN.index / (g_all_state.m_num_profiles - 1);
	float pre_evaluated_scalar[_index_max]= preevaluate_light_volume_functions(STATE);

	// Update pos
	STATE.m_position.xyz= g_all_state.m_origin + g_all_state.m_direction * (g_all_state.m_offset + g_all_state.m_profile_distance * IN.index);

	// Compute color (will be clamped [0,1] and compressed to 8-bit upon export)
	STATE.m_color.xyz= light_volume_map_to_color_range(_index_profile_color, 
		pre_evaluated_scalar[_index_profile_color]);
	STATE.m_color.w= pre_evaluated_scalar[_index_profile_alpha];
		
	// Compute misc fields (better to do once here than multiple times in render)
	STATE.m_thickness= pre_evaluated_scalar[_index_profile_thickness];
	STATE.m_intensity= pre_evaluated_scalar[_index_profile_intensity];

	//return 
	write_profile_state(STATE, buffer_index);
}
#endif	// #ifndef pc

// For EDRAM method, the main work must go in the pixel shader, since only 
// pixel shaders can write to EDRAM.
// For the MemExport method, we don't need a pixel shader at all.
// This is signalled by a "void" return type or "multipass" config?

#ifdef pc
float4 default_vs( vertex_type IN ) :POSITION
{
	return float4(1, 2, 3, 4);
}
#else
void default_vs( vertex_type IN )
{
//	asm {
//		config VsExportMode=multipass   // export only shader
//	};
	light_volume_main(IN);
}
#endif

#endif	//#ifdef VERTEX_SHADER

// Should never be executed
float4 default_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}

