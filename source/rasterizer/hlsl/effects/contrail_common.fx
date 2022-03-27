// These are the constants which we don't want to overwrite.  They need to 
// be declared here, whether or not we use them, so that the shader compiler 
// will not auto-assign things to them.

#ifndef pc

#include "effects\function.fx"	// For evaluating Guerilla functions

#define _register_group_properties		3
#define _register_group_memexport		4

// Match with c_contrail_gpu anonymous enum
#define k_profiles_per_row	16 
#define k_row_count			64 
static int2 g_buffer_dims= int2(k_profiles_per_row, k_row_count);

// Match with the fields of c_contrail_gpu::s_layout.
struct s_profile_state
{
	float3	m_position;
	float3	m_velocity;
	float	m_rotation;
	float	m_lifespan;
	float	m_age;
	float4	m_color;
	float4	m_initial_color;
	float	m_initial_alpha;
	float4	m_random;
	float	m_size;
	float	m_intensity;
	float	m_black_point;
	float	m_palette;
	float2	m_offset;
	float	m_length;
	float	m_dummy;	// this works around an internal compiler error
};

#ifdef READ_DISABLE_FOR_DEBUGGING
// Choose something which won't cause the profile lifetime to be up...
extern float4 unknown_value : register(k_register_camera_forward);
#endif

s_profile_state read_profile_state(int index)
{
	s_profile_state STATE;
	
#ifndef READ_DISABLE_FOR_DEBUGGING
	// Match with c_contrail_gpu::e_state, and with c_contrail_gpu::queue_profile().
	// Note that because of format specifications, state fields must be carefully assigned 
	// to an appropriate sample.
	float4 pos_sample;
	float4 vel_sample;
	float4 rnd_sample;
	float4 misc_sample_4x16f;
	float4 misc_sample_4x16un;
	float4 misc_sample_2x16f;
	float4 col_sample;
	float4 col2_sample;

	asm {
		vfetch pos_sample, index.x, position
		vfetch vel_sample, index.x, position1
		vfetch rnd_sample, index.x, position2
		vfetch misc_sample_4x16f, index.x, texcoord0
		vfetch misc_sample_4x16un, index.x, texcoord2
		vfetch misc_sample_2x16f, index.x, texcoord3
		vfetch col_sample, index.x, color
		vfetch col2_sample, index.x, color1
	};
#else
	float4 pos_sample= unknown_value;
	float4 vel_sample= unknown_value;
	float4 rnd_sample= unknown_value;
	float4 misc_sample_4x16f= unknown_value;
	float4 misc_sample_4x16un= unknown_value;
	float4 misc_sample_2x16f= unknown_value;
	float4 col_sample= unknown_value;
	float4 col2_sample= unknown_value;
#endif

	// This code basically compiles away, since it's absorbed into the
	// compiler's register mapping.
	STATE.m_position= pos_sample.xyz;			// s_gpu_storage_4x32f
	STATE.m_age= pos_sample.w;
	STATE.m_velocity= vel_sample.xyz;			// s_gpu_storage_4x16f --- doesn't get fetched from render
	STATE.m_initial_alpha= vel_sample.w;
	STATE.m_random= rnd_sample;					// s_gpu_storage_4x16un --- doesn't get fetched from render
	STATE.m_size= misc_sample_4x16f.x;			// s_gpu_storage_4x16f --- doesn't get fetched from update
	STATE.m_intensity= misc_sample_4x16f.y;
	STATE.m_offset= misc_sample_4x16f.zw;
	STATE.m_rotation= misc_sample_4x16un.x;		// s_gpu_storage_4x16un --- doesn't get fetched from update
	STATE.m_black_point= misc_sample_4x16un.y;
	STATE.m_palette= misc_sample_4x16un.z;
	STATE.m_length= misc_sample_2x16f.x;		// s_gpu_storage_2x16f
	STATE.m_lifespan= misc_sample_2x16f.y;
	STATE.m_color= col_sample;					// s_gpu_storage_argb8 --- doesn't get fetched from update
	STATE.m_initial_color= col2_sample;				// s_gpu_storage_argb8 --- doesn't get fetched from update
	
	return STATE;
}

#ifdef MEMEXPORT_ENABLED

// Match with c_contrail_gpu::e_state.
#define _state_pos			0
#define _state_vel			1
#define	_state_rnd			2
#define _state_misc_4x16f	3
#define _state_misc_4x16un	4
#define _state_misc_2x16f	5
#define _state_col			6
#define _state_col2			7
#define _state_max			8

// Match with s_memexport in s_gpu_layout<t_num_states>::set_memexport()
struct s_memexport
{
	float4 m_stream_constant;
	float2 m_stride_offset;
};

BEGIN_REGISTER_GROUP(memexport)
extern s_memexport g_all_memexport[_state_max];
END_REGISTER_GROUP(memexport)

// The including function must define the stride_offset and stream_constant registers.
void write_profile_state(s_profile_state STATE, int index)
{
	static float4 stream_helper= {0, 1, 0, 0};
	float4 export[_state_max];

	// This code basically compiles away, since it's absorbed into the
	// compiler's register mapping.
	export[_state_pos]= float4(STATE.m_position, STATE.m_age);
	export[_state_vel]= float4(STATE.m_velocity, STATE.m_initial_alpha);
	export[_state_rnd]= float4(STATE.m_random);
	export[_state_misc_4x16f]= float4(STATE.m_size, STATE.m_intensity, STATE.m_offset);
	export[_state_misc_4x16un]= float4(STATE.m_rotation, STATE.m_black_point, STATE.m_palette, 0.0f);
	export[_state_misc_2x16f]= float4(STATE.m_length, STATE.m_lifespan, 0.0f, 0.0f);
	export[_state_col]= float4(STATE.m_color);
	export[_state_col2]= float4(STATE.m_initial_color);
#ifndef WRITE_DISABLE_FOR_PROFILING
    // Store result.  Some of these writes are not needed by all clients
    // (eg. rnd should only be written by spawn, not update).
    for (int state= 0; state< _state_max; ++state)
    {
		int state_index= index * g_all_memexport[state].m_stride_offset.x + g_all_memexport[state].m_stride_offset.y;
		float4 stream_constant= g_all_memexport[state].m_stream_constant;
		float4 export= export[state];
		asm {
		alloc export=1
			mad eA, state_index, stream_helper, stream_constant
			mov eM0, export
		};
    }
    // This is a workaround for a bug in >=Profile builds.  Without it, we get occasional 
    // bogus memexports from nowhere during effect-heavy scenes.
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.y, hidden_from_compiler.yyyy, hidden_from_compiler.yyyy
	};
	asm {
	alloc export=1
		mad eA.xyzw, hidden_from_compiler.z, hidden_from_compiler.zzzz, hidden_from_compiler.zzzz
	};
#else	// do only enough writing to keep from culling any ALU calculations
	float4 all_export= float4(0,0,0,0);
    for (int state= 0; state< _state_max; ++state)
    {
		all_export+= export[state];
    }
	int state_index= index * g_all_memexport[0].m_stride_offset.x + g_all_memexport[0].m_stride_offset.y;
	float4 stream_constant= g_all_memexport[0].m_stream_constant;
	asm {
	alloc export=1
		mad eA, state_index, stream_helper, stream_constant
		mov eM0, all_export
	};
#endif
}

#endif	//#ifdef MEMEXPORT_ENABLED

// Match with c_contrail_definition::e_appearance_flags
#define _contrail_tint_from_lightmap_bit			0	//_tint_from_lightmap_bit, 
#define _contrail_double_sided_bit					1	//_double_sided_bit, 
#define _contrail_profile_opacity_from_scale_a_bit	2	//_profile_opacity_from_scale_a_bit, 
#define _contrail_random_u_offset_bit				3	//_random_u_offset_bit, 
#define _contrail_random_v_offset_bit				4	//_random_v_offset_bit, 
#define _contrail_origin_faded_bit					5	//_origin_faded_bit, 
#define _contrail_edge_faded_bit					6	//_edge_faded_bit, 
#define _contrail_fogged_bit						7	//_fogged_bit, 

// Match with c_contrail_state::e_input
#define _state_profile_age				0	//_profile_age
#define _state_profile_random			1	//_profile_random
#define _state_profile_correlation_1	2	//_profile_correlation_1
#define _state_profile_correlation_2	3	//_profile_correlation_2
#define _state_profile_correlation_3	4	//_profile_correlation_3
#define _state_profile_correlation_4	5	//_profile_correlation_4
#define _state_game_time				6	//_game_time
#define _state_system_age				7	//_system_age 
#define _state_contrail_random			8	//_contrail_random 
#define _state_contrail_correlation_1	9	//_contrail_correlation_1
#define _state_contrail_correlation_2	10	//_contrail_correlation_2
#define _state_location_speed			11	//_location_speed 
#define _state_system_lod				12	//_system_lod 
#define _state_effect_a_scale			13	//_effect_a_scale
#define _state_effect_b_scale			14	//_effect_b_scale
#define _state_invalid					15	//_invalid
#define _state_total_count				16	//k_total_count
	
// Match with s_overall_state in c_contrail_gpu::set_shader_state()
struct s_gpu_single_state
{
	float m_value;
};
struct s_fade
{
	float4 m__origin_range__origin_cutoff__edge_range__edge_cutoff;
#define m_origin_range		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.x
#define m_origin_cutoff		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.y
#define m_edge_range		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.z
#define m_edge_cutoff		m_fade.m__origin_range__origin_cutoff__edge_range__edge_cutoff.w
};
struct s_overall_state
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
	s_gpu_single_state m_inputs[_state_total_count];
};

extern s_overall_state g_all_state;

// Match with c_editable_property_base::e_output_modifier
#define _modifier_none			0	//_output_modifier_none
#define _modifier_add			1	//_output_modifier_add
#define _modifier_multiply		2	//_output_modifier_multiply

float get_state_value(const s_profile_state profile_state, int index)
{
	if (index== _state_profile_age)
	{
		return profile_state.m_age;
	}
	else if (index<= _state_profile_correlation_4)
	{
		return profile_state.m_random[index-_state_profile_correlation_1];
	}
	else	// a state which is independent of profile
	{
		return g_all_state.m_inputs[index].m_value;
	}
}

// Match with s_gpu_property.  
// The s_property struct is implemented internally with bitfields to save constant space.
// The EXTRACT_BITS macro should take 2-5 assembly instructions depending on whether the bits
// lie at the beginning/middle/end of the allowed range.
struct s_property 
{
	float4 m_innards;
};
float get_constant_value(s_property p)		{ return p.m_innards.x; }
int get_is_constant(s_property p)			{ return EXTRACT_BITS(p.m_innards.y, 21, 22); }	// 1 bit always
int get_function_index_green(s_property p)	{ return EXTRACT_BITS(p.m_innards.z, 17, 22); }	// 5 bits often	
int get_input_index_green(s_property p)		{ return EXTRACT_BITS(p.m_innards.w, 17, 22); }	// 5 bits often	
int get_function_index_red(s_property p)	{ return EXTRACT_BITS(p.m_innards.y, 0, 5); }	// 5 bits often	
int get_input_index_red(s_property p)		{ return EXTRACT_BITS(p.m_innards.y, 5, 10); }	// 5 bits rarely	
int get_color_index_lo(s_property p)		{ return EXTRACT_BITS(p.m_innards.w, 0, 3); }	// 3 bits rarely	
int get_color_index_hi(s_property p)		{ return EXTRACT_BITS(p.m_innards.w, 3, 6); }	// 3 bits rarely	
int get_modifier_index(s_property p)		{ return EXTRACT_BITS(p.m_innards.z, 0, 2); }	// 2 bits often	
int get_input_index_modifier(s_property p)	{ return EXTRACT_BITS(p.m_innards.z, 2, 7); }	// 5 bits rarely	

// Match with e_property in c_contrail_gpu::set_shader_functions().
// Keep the index_ and bit_ #defines in sync!
#define _index_profile_self_acceleration	0
#define _index_profile_size					1
#define _index_profile_offset				2
#define _index_profile_rotation				3
#define _index_profile_rotation_rate		4
#define _index_profile_color				5
#define _index_profile_alpha				6
#define _index_profile_alpha2				7
#define _index_profile_black_point			8
#define _index_profile_intensity			9
#define _index_profile_palette				10
#define _index_max							11

BEGIN_REGISTER_GROUP(properties)
extern s_property g_all_properties[_index_max];
END_REGISTER_GROUP(properties)

// This generates multiple inlined calls to evaluate and get_state_value, which are 
// large functions.  If the inlining becomes an issue, we can use the loop 
// trick documented below.
float profile_evaluate(const s_profile_state profile_state, int type)
{
	s_property property= g_all_properties[type];
	if (get_is_constant(property))
	{
		return get_constant_value(property);
	}
	else
	{
		float input= get_state_value(profile_state, get_input_index_green(property));
		float output;
		if (get_function_index_red(property)!= _type_identity)	// hack for ranged, since 0 isn't used
		{
			float interpolate= get_state_value(profile_state, get_input_index_red(property));
			output= evaluate_scalar_ranged(get_function_index_green(property), get_function_index_red(property), input, 
				interpolate);
		}
		else
		{
			output= evaluate_scalar(get_function_index_green(property), input);
		}
		if (get_modifier_index(property)!= _modifier_none)
		{
			float modify_by= get_state_value(profile_state, get_input_index_modifier(property));
			if (get_modifier_index(property)== _modifier_add)
			{
				output+= modify_by;
			}
			else // if (get_modifier_index(property)== _modifier_multiply)
			{
				output*= modify_by;
			}
		}
		return output;
	}
}

float3 contrail_map_to_color_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_color_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

float2 contrail_map_to_vector2d_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_vector2d_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

float3 contrail_map_to_vector3d_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_vector3d_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

typedef float preevaluated_functions[_index_max];
preevaluated_functions preevaluate_contrail_functions(s_profile_state STATE)
{
	// The explicit initializations below are necessary to avoid uninitialized
	// variable errors.  I believe the excess initializations are stripped out.
	float pre_evaluated_scalar[_index_max]= {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
	[loop]
	for (int loop_counter= 0; loop_counter< _index_max; ++loop_counter)
	{
		pre_evaluated_scalar[loop_counter]= profile_evaluate(STATE, loop_counter);
	}

	return pre_evaluated_scalar;
}

#endif	// #ifndef pc