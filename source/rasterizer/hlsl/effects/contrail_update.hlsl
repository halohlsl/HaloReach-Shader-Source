/*
CONTRAIL_UPDATE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for contrail physics, state updates
*/

#include "hlsl_constant_globals.fx"

#if DX_VERSION == 11
// @compute_shader
#endif

#include "effects\contrail_update_registers.fx"	// must come before contrail_common.fx
#include "effects\contrail_registers.fx"

#if ((DX_VERSION == 9) && (defined(VERTEX_SHADER))) || ((DX_VERSION == 11) && defined(COMPUTE_SHADER))

#define MEMEXPORT_ENABLED 1

#include "hlsl_vertex_types.fx"
#include "effects\contrail_common.fx"

//This comment causes the shader compiler to be invoked for certain types
//@generate contrail

typedef s_contrail_vertex s_profile_in;
typedef void s_profile_out;

#if !defined(pc) || (DX_VERSION == 11)

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

#if defined(pc) && (DX_VERSION == 9)
float4 default_vs( vertex_type IN ) :POSITION
{
	return float4(1, 2, 3, 4);
}

#elif DX_VERSION == 9

void default_vs( vertex_type IN )
{
//	asm {
//		config VsExportMode=multipass   // export only shader
//	};

	contrail_main(IN);
}

#elif (DX_VERSION == 11) && defined(COMPUTE_SHADER)
[numthreads(CS_CONTRAIL_UPDATE_THREADS,1,1)]
void default_cs(in uint raw_index : SV_DispatchThreadID)
{
	if (raw_index < contrail_index_range.y)
	{
		uint row_index = raw_index >> k_contrail_row_shift;
		uint col_index = raw_index & k_contrail_row_mask;
		s_particle_row row = particle_row_buffer[contrail_index_range.x + row_index];
		uint count = row.system_count & k_contrail_row_mask;
		if (col_index <= count) // count is actually (count - 1)
		{
			g_update_params_index = (row.system_count >> k_contrail_update_params_shift) & k_contrail_update_params_mask;
			g_const_params_index = (row.system_count >> k_contrail_const_params_shift) & k_contrail_const_params_mask;		
			
			vertex_type input;
			input.index = row.start + col_index;
			contrail_main(input);
		}
	}
}
#endif
//#endif

#endif

#if DX_VERSION == 9
// Should never be executed
float4 default_ps( void ) :SV_Target0
{
	return float4(0,1,2,3);
}
#endif

