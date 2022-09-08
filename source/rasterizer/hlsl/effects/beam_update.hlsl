/*
BEAM_UPDATE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for beam physics, state updates
*/

#include "hlsl_constant_globals.fx"

#if DX_VERSION == 11
// @compute_shader
#endif

#if ((DX_VERSION == 9) && defined(VERTEX_SHADER)) || ((DX_VERSION == 11) && defined(COMPUTE_SHADER))


#define MEMEXPORT_ENABLED 1

#include "hlsl_vertex_types.fx"
#include "effects\beam_update_registers.fx"
#include "effects\beam_common.fx"


//This comment causes the shader compiler to be invoked for certain types
//@generate beam

typedef s_beam_vertex s_profile_in;
typedef void s_profile_out;

#if !defined(pc) || (DX_VERSION == 11)

s_profile_out beam_main( 
	s_profile_in IN 
#if DX_VERSION == 11
	, int buffer_index
#endif	
	)
{
	s_profile_state STATE;
	s_profile_out OUT;
#if DX_VERSION == 9	
	int buffer_index= profile_index_to_buffer_index(IN.index);
#endif
	//STATE= read_profile_state(buffer_index);	// Beams are stateless


	STATE.m_percentile= (IN.index== g_all_state.m_num_profiles - 1)
		? 1.0f
		: IN.index * g_all_state.m_percentile_step;
   float pre_evaluated_scalar[_index_max]= preevaluate_beam_functions(STATE);

	// Update pos
	STATE.m_position= g_all_state.m_origin + g_all_state.m_direction * (g_all_state.m_offset_overall + g_all_state.m_capped_length * STATE.m_percentile);
	STATE.m_offset= float2(0.0f, 0.0f);//beam_map_to_point2d_range(_index_profile_offset, pre_evaluated_scalar[_index_profile_offset]);

	// Compute color (will be clamped [0,1] and compressed to 8-bit upon export)
	STATE.m_color.xyz= beam_map_to_color_range(_index_profile_color, pre_evaluated_scalar[_index_profile_color]);
	STATE.m_color.w= pre_evaluated_scalar[_index_profile_alpha];

	// Compute misc fields (better to do once here than multiple times in render)
	STATE.m_rotation= pre_evaluated_scalar[_index_profile_rotation];
	STATE.m_thickness= pre_evaluated_scalar[_index_profile_thickness];
	STATE.m_black_point= pre_evaluated_scalar[_index_profile_black_point];
	STATE.m_palette= pre_evaluated_scalar[_index_profile_palette];
	STATE.m_intensity= pre_evaluated_scalar[_index_profile_intensity];

	//return
   write_profile_state(STATE, buffer_index);
}
#endif	// #ifndef pc

// For EDRAM method, the main work must go in the pixel shader, since only
// pixel shaders can write to EDRAM.
// For the MemExport method, we don't need a pixel shader at all.
// This is signalled by a "void" return type or "multipass" config?

#if defined(pc) && (DX_VERSION == 9)
float4 default_vs( vertex_type IN ) :SV_Position
{
	return float4(1, 2, 3, 4);
}
#else

#if DX_VERSION == 9
void default_vs( vertex_type IN )
{
//	asm {
//		config VsExportMode=multipass   // export only shader
//	};
	beam_main(IN);
}
#elif DX_VERSION == 11
[numthreads(CS_BEAM_UPDATE_THREADS,1,1)]
void default_cs(in uint raw_index : SV_DispatchThreadID)
{
	if (raw_index < beam_index_range.y)
	{
		uint row_index = raw_index >> k_beam_row_shift;
		uint col_index = raw_index & k_beam_row_mask;
		s_particle_row row = particle_row_buffer[beam_index_range.x + row_index];
		uint count = row.system_count & k_beam_row_mask;
		if (col_index <= count) // count is actually (count - 1)
		{
			g_update_params_index = (row.system_count >> k_beam_update_params_shift) & k_beam_update_params_mask;
			g_const_params_index = (row.system_count >> k_beam_const_params_shift) & k_beam_const_params_mask;		
		
			uint strip_row = (row.start >> 16);
			uint buffer_row = (row.start & 0xffff);				
		
			s_profile_in input;
			input.index = strip_row + col_index;
			beam_main(input, buffer_row + col_index);
		}		
	}
}
#endif
#endif

#else //VERTEX_SHADER

// Should never be executed
#if DX_VERSION == 9
float4 default_ps( SCREEN_POSITION_INPUT(screen_position) ) : SV_Target0
{
	return float4(0,1,2,3);
}
#endif

#endif