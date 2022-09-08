#ifndef _BEAM_STATE_LIST_FX_
#define _BEAM_STATE_LIST_FX_

#ifndef DEFINE_CPP_CONSTANTS
// Match with c_beam_definition::e_appearance_flags
#define _beam_double_sided_bit			0	//_double_sided_bit,
#define _beam_origin_faded_bit			1	//_origin_faded_bit,
#define _beam_edge_faded_bit			2	//_edge_faded_bit,
#define _beam_fogged_bit				3	//_fogged_bit,
#define _beam_angle_faded_bit			4	//_angle_faded_bit,


// Match with c_beam_state::e_input
#define _profile_capped_percentile		0	//_profile_capped_percentile
#define _profile_uncapped_percentile	1	//_profile_uncapped_percentile
#define _game_time						2	//_game_time
#define _system_age						3	//_system_age
#define _beam_random					4	//_beam_random
#define _beam_correlation_1				5	//_beam_correlation_1
#define _beam_correlation_2				6	//_beam_correlation_2
#define _beam_length					7	//_beam_length
#define _system_lod						8	//_system_lod
#define _effect_a_scale					9	//_effect_a_scale
#define _effect_b_scale					10	//_effect_b_scale
#define _invalid						11	//_invalid
#endif
#define _state_total_count				12	//k_total_count


// Match with s_overall_state in c_beam_gpu::set_shader_state()
struct s_gpu_single_state
{
	PADDED(float, 1, m_value)
};


struct s_floats
{
	float4 m__profile_type__ngon_sides__appearance_flags__offset;
	float4 m__num_profiles__percentile_step__capped_length__cap_percentage;
#ifndef DEFINE_CPP_CONSTANTS
#define m_profile_type		m_floats.m__profile_type__ngon_sides__appearance_flags__offset.x
#define m_ngon_sides		m_floats.m__profile_type__ngon_sides__appearance_flags__offset.y
#define m_appearance_flags	m_floats.m__profile_type__ngon_sides__appearance_flags__offset.z
#define m_offset_overall	m_floats.m__profile_type__ngon_sides__appearance_flags__offset.w
#define m_num_profiles		m_floats.m__num_profiles__percentile_step__capped_length__cap_percentage.x
#define m_percentile_step	m_floats.m__num_profiles__percentile_step__capped_length__cap_percentage.y
#define m_capped_length		m_floats.m__num_profiles__percentile_step__capped_length__cap_percentage.z
#define m_cap_percentage	m_floats.m__num_profiles__percentile_step__capped_length__cap_percentage.w
#endif
};


struct s_fade
{
	float4 m__origin_range__origin_cutoff__edge_range__edge_cutoff;
	float4 m__angle_range__angle_cutoff__pad_0__pad_1;
#ifndef DEFINE_CPP_CONSTANTS
#define m_origin_range		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.x
#define m_origin_cutoff		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.y
#define m_edge_range		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.z
#define m_edge_cutoff		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.w
#define m_angle_range		m_fade.m__angle_range__angle_cutoff__pad_0__pad_1.x
#define m_angle_cutoff		m_fade.m__angle_range__angle_cutoff__pad_0__pad_1.y
#endif
};


struct s_overall_state
{
	s_floats m_floats;
	PADDED(float, 2, m_uv_tiling_rate)
	PADDED(float, 2, m_uv_scroll_rate)
	PADDED(float, 1, m_game_time)
	PADDED(float, 3, m_origin)
	PADDED(float, 3, m_direction)
	s_fade m_fade;
	s_gpu_single_state m_inputs[_state_total_count];
};

#endif
