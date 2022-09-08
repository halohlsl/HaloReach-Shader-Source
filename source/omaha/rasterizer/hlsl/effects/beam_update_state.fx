#ifndef _BEAM_UPDATE_STATE_FX_
#define _BEAM_UPDATE_STATE_FX_

#include "effects\beam_property.fx"
#include "effects\function_definition.fx"
#include "effects\beam_state_list.fx"

struct s_gpu_single_state_update
{
	float m_value;
};

struct s_overall_state_update
{
	s_floats m_floats;
	float2 m_uv_tiling_rate;
	float2 m_uv_scroll_rate;
	float m_game_time;
	float3 m_origin;
	float3 m_direction;
	s_fade m_fade;
	s_gpu_single_state_update m_inputs[_state_total_count];
};

struct s_beam_system_const_params
{
	s_property all_properties[_index_max];
	s_function_definition all_functions[_maximum_overall_function_count];
	float4 all_colors[_maximum_overall_color_count];
};

struct s_beam_system_update_params
{
	s_overall_state_update all_state;
};

#endif
