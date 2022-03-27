/*
CONTRAIL_UPDATE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for contrail physics, state updates
*/

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
#include "effects\contrail_update_registers.fx"	// must come before contrail_common.fx
#include "effects\contrail_common.fx"

//This comment causes the shader compiler to be invoked for certain types
//@generate contrail

typedef s_contrail_vertex s_profile_in;
typedef void s_profile_out;

#ifndef pc

s_profile_out contrail_main( s_profile_in IN )
{
	s_profile_state STATE;
	s_profile_out OUT;

	STATE= read_profile_state(IN.index);

	float pre_evaluated_scalar[_index_max]= preevaluate_contrail_functions(STATE);

	// Shader compiler workaround ... the shader doesn't compile on Feb 2007 XDK unless we move this line earliery
	STATE.m_offset= contrail_map_to_vector2d_range(_index_profile_offset, 
		pre_evaluated_scalar[_index_profile_offset]);
		
	if( STATE.m_age < 1.0f )
	{
		// Update timer
		STATE.m_age+= delta_time / STATE.m_lifespan;

		// Update pos
		STATE.m_position.xyz+= STATE.m_velocity.xyz * delta_time;

		// Update velocity
		STATE.m_velocity+= contrail_map_to_vector3d_range(_index_profile_self_acceleration, 
			pre_evaluated_scalar[_index_profile_self_acceleration]) * delta_time;
		
		// Update rotation (only stored as [0,1], and "frac" is necessary to avoid clamping)
		STATE.m_rotation= frac(pre_evaluated_scalar[_index_profile_rotation]);
		
		// Compute color (will be clamped [0,1] and compressed to 8-bit upon export)
		STATE.m_color.xyz= contrail_map_to_color_range(_index_profile_color, 
			pre_evaluated_scalar[_index_profile_color]);
		STATE.m_color.w= pre_evaluated_scalar[_index_profile_alpha] * pre_evaluated_scalar[_index_profile_alpha2];
			
		// Compute misc fields (better to do once here than multiple times in render)
		STATE.m_size= pre_evaluated_scalar[_index_profile_size];
		STATE.m_intensity= pre_evaluated_scalar[_index_profile_intensity];
		STATE.m_black_point= frac(pre_evaluated_scalar[_index_profile_black_point]);
		STATE.m_palette= frac(pre_evaluated_scalar[_index_profile_palette]);
		//STATE.m_offset= contrail_map_to_vector2d_range(_index_profile_offset, 
		//	pre_evaluated_scalar[_index_profile_offset]);
	}

	//return 
	write_profile_state(STATE, IN.index);
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
	contrail_main(IN);
}
#endif

#endif //VERTEX_SHADER

// Should never be executed
float4 default_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}

