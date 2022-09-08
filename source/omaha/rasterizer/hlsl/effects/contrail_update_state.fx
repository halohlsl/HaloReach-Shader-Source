#ifndef _CONTRAIL_UPDATE_STATE_
#define _CONTRAIL_UPDATE_STATE_

#include "effects\contrail_property.fx"
#include "effects\function_definition.fx"
#include "effects\contrail_state.fx"

struct s_gpu_single_state_update
{
	float m_value;
};
struct s_overall_state_update
{
	float m_profile_type;
	float m_ngon_sides;
	float m_appearance_flags;
	float m_num_profiles;
	float2 m_uv_tiling_rate;
	float2 m_uv_scroll_rate;
	float2 m_uv_offset;
	float m_game_time;
	float3 m_origin;
	s_fade m_fade;
	s_gpu_single_state_update m_inputs[_state_total_count];
};

struct s_contrail_system_const_params
{
	s_property all_properties[_index_max];
	s_function_definition all_functions[_maximum_overall_function_count];
	float4 all_colors[_maximum_overall_color_count];
};

struct s_contrail_system_update_params
{
	s_overall_state_update all_state;
};

#endif
