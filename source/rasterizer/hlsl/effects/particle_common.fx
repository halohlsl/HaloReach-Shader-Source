// These are the constants which we don't want to overwrite.  They need to 
// be declared here, whether or not we use them, so that the shader compiler 
// will not auto-assign things to them.

#ifndef pc

#ifndef PARTICLE_NO_PROPERTY_EVALUATE
	#include "effects\function.fx"	// For evaluating Guerilla functions
#endif	//#ifndef PARTICLE_NO_PROPERTY_EVALUATE

#define _register_group_properties		3
#define _register_group_memexport		4

#define _dies_at_rest_bit					0 //_particle_dies_at_rest_bit
#define _dies_on_structure_collision_bit	1 //_particle_dies_on_structure_collision_bit
#define _dies_on_media_collision_bit		2 //_particle_dies_on_media_collision_bit
#define _dies_on_air_collision_bit			3 //_particle_dies_on_air_collision_bit
#define _has_sweetener_bit					4 //_particle_has_sweetener_bit

#define _randomly_flip_u_bit				0 //_particle_randomly_flip_u_bit
#define _randomly_flip_v_bit				1 //_particle_randomly_flip_v_bit
#define _random_starting_rotation_bit		2 //_particle_random_starting_rotation_bit
#define _tint_from_lightmap_bit				3 //_particle_tint_from_lightmap_bit
#define _tint_from_diffuse_texture_bit		4 //_particle_tint_from_diffuse_texture_bit
#define _source_bitmap_vertical_bit			5 //_particle_source_bitmap_vertical_bit
#define _intensity_affects_alpha_bit		6 //_particle_intensity_affects_alpha_bit
#define _fade_near_edge_bit					7 //_particle_fade_near_edge_bit
#define _motion_blur_bit					8 //_particle_motion_blur_bit
#define _double_sided_bit					9 //_particle_double_sided_bit
#define _fogged_bit							10//_particle_fogged_bit
#define _lightmap_lit_bit					11 //_particle_lightmap_lit_bit
#define _depth_fade_active_bit				12 //_particle_depth_fade_active_bit
#define _distortion_active_bit				13 //_particle_distortion_active_bit
#define _ldr_only_bit						14 //_particle_ldr_only_bit
#define _is_particle_model_bit				15 //_particle_is_particle_model_bit

#define _frame_animation_one_shot_bit		0 //_particle_frame_animation_one_shot_bit
#define _can_animate_backwards_bit			1 //_particle_can_animate_backwards_bit

#define _modifier_none			0
#define _modifier_add			1
#define _modifier_multiply		2

#ifndef PARTICLE_NO_PROPERTY_EVALUATE

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

// keep the index_ and bit_ #defines in sync!
#define _index_emitter_tint			0
#define _index_emitter_alpha		1
#define _index_emitter_size			2
#define _index_particle_color		3
#define _index_particle_intensity	4
#define _index_particle_alpha		5
#define _index_particle_scale		6
#define _index_particle_rotation	7
#define _index_particle_frame		8
#define _index_particle_black_point	9
#define _index_particle_aspect		10
#define _index_particle_self_acceleration 11
#define _index_particle_palette		12
#define _index_emitter_movement_turbulence 13
#define _index_max					14

BEGIN_REGISTER_GROUP(properties)
extern s_property g_all_properties[_index_max];
END_REGISTER_GROUP(properties)

#endif	//#ifndef PARTICLE_NO_PROPERTY_EVALUATE

struct s_particle_state
{
	float3	m_position;
	float3	m_velocity;
	float3	m_axis;
	float	m_physical_rotation;
	float	m_manual_rotation;
	float	m_animated_frame;
	float	m_manual_frame;
	float	m_rotational_velocity;
	float	m_frame_velocity;
	float	m_birth_time;
	float	m_inverse_lifespan;
	float	m_age;
	float4	m_color;
	float4	m_initial_color;
	float4	m_random;
	float4	m_random2;
	float	m_size;
	float	m_aspect;
	float	m_intensity;
	float	m_black_point;
	float	m_palette_v;
	float	m_game_simulation_a;
	float	m_game_simulation_b;
};

#ifdef PARTICLE_READ_DISABLE_FOR_DEBUGGING
// Choose something which won't cause the particle lifetime to be up...
extern float4 unknown_value : register(k_register_camera_forward);
#endif

s_particle_state read_particle_state(int index)
{
	s_particle_state STATE;
	
#ifndef PARTICLE_READ_DISABLE_FOR_DEBUGGING
	float4 pos_sample;
	float4 vel_sample;
	float4 rot_sample;
	float4 time_sample;
	float4 anm_sample;
	float4 anm2_sample;
	float4 rnd_sample;
	float4 rnd2_sample;
	float4 axis_sample;
	float4 col_sample;
	float4 col2_sample;

	asm {
		vfetch pos_sample, index.x, position1
		vfetch vel_sample, index.x, position2
		vfetch rot_sample, index.x, texcoord2
		vfetch time_sample, index.x, texcoord3
		vfetch anm_sample, index.x, texcoord4
		vfetch anm2_sample, index.x, texcoord5
		vfetch rnd_sample, index.x, position3
		vfetch rnd2_sample, index.x, position4
		vfetch axis_sample, index.x, normal1
		vfetch col_sample, index.x, color
		vfetch col2_sample, index.x, color1
	};
#else
	float4 pos_sample= unknown_value;
	float4 vel_sample= unknown_value;
	float4 rot_sample= unknown_value;
	float4 time_sample= unknown_value;
	float4 anm_sample= unknown_value;
	float4 rnd_sample= unknown_value;
	float4 rnd2_sample= unknown_value;
	float4 axis_sample= unknown_value;
	float4 col_sample= unknown_value;
	float4 col2_sample= unknown_value;
#endif

	// This code basically compiles away, since it's absorbed into the
	// compiler's register mapping.
	STATE.m_position= pos_sample.xyz;
	STATE.m_velocity= vel_sample.xyz;
	STATE.m_axis= axis_sample.xyz;
	STATE.m_birth_time= time_sample.x;
	STATE.m_age= time_sample.z;
	STATE.m_inverse_lifespan= time_sample.y;
	STATE.m_physical_rotation= rot_sample.x;
	STATE.m_manual_rotation= rot_sample.y;
	STATE.m_animated_frame= rot_sample.z;
	STATE.m_manual_frame= rot_sample.w;
	STATE.m_rotational_velocity= anm_sample.x;
	STATE.m_frame_velocity= anm_sample.y;
	STATE.m_color= col_sample;
	STATE.m_initial_color= col2_sample;
	STATE.m_random= rnd_sample;
	STATE.m_random2= rnd2_sample;
	STATE.m_size= pos_sample.w;
	STATE.m_aspect= vel_sample.w;
	STATE.m_intensity= time_sample.w;
	STATE.m_black_point= anm2_sample.x;
	STATE.m_palette_v= anm2_sample.y;
	STATE.m_game_simulation_a= anm_sample.z;
	STATE.m_game_simulation_b= anm_sample.w;
	
	return STATE;
}


s_particle_state read_particle_state_fast(int index)
{
	s_particle_state STATE;
	
	float4 pos_sample;
//	float4 vel_sample;			// unused
	float4 rot_sample;
	float4 time_sample;
//	float4 anm_sample;			// unused
	float4 anm2_sample;
//	float4 rnd_sample;
//	float4 rnd2_sample;			// unused
	float4 axis_sample;			// unused
	float4 col_sample;
	float4 col2_sample;

	asm {
		vfetch pos_sample, index.x, position1
//		vfetch vel_sample, index.x, position2
		vfetch rot_sample, index.x, texcoord2
		vfetch time_sample, index.x, texcoord3
//		vfetch anm_sample, index.x, texcoord4
		vfetch anm2_sample, index.x, texcoord5
//		vfetch rnd_sample, index.x, position3
//		vfetch rnd2_sample, index.x, position4
		vfetch axis_sample, index.x, normal1
		vfetch col_sample, index.x, color
		vfetch col2_sample, index.x, color1
	};

//	float4 pos_sample= unknown_value;
	float4 vel_sample= 0;
//	float4 rot_sample= unknown_value;
//	float4 time_sample= unknown_value;
	float4 anm_sample= 0;
	float4 rnd_sample= 0;
	float4 rnd2_sample= 0;
//	float4 axis_sample= 0;
//	float4 col_sample= unknown_value;
//	float4 col2_sample= unknown_value;

	// This code basically compiles away, since it's absorbed into the
	// compiler's register mapping.
	STATE.m_position= pos_sample.xyz;				// used
	STATE.m_velocity= vel_sample.xyz;
	STATE.m_axis= axis_sample.xyz;					// used
	STATE.m_birth_time= time_sample.x;
	STATE.m_age= time_sample.z;						// used
	STATE.m_inverse_lifespan= time_sample.y;
	STATE.m_physical_rotation= rot_sample.x;		// used
	STATE.m_manual_rotation= rot_sample.y;			// used
	STATE.m_animated_frame= rot_sample.z;			// used
	STATE.m_manual_frame= rot_sample.w;				// used
	STATE.m_rotational_velocity= anm_sample.x;
	STATE.m_frame_velocity= anm_sample.y;
	STATE.m_color= col_sample;						// xyzw used
	STATE.m_initial_color= col2_sample;				// xyzw used
	STATE.m_random= rnd_sample;						// z used
	STATE.m_random2= rnd2_sample;
	STATE.m_size= pos_sample.w;						// used
	STATE.m_aspect= 1.0f;							// vel_sample.w;
	STATE.m_intensity= time_sample.w;				// used
	STATE.m_black_point= anm2_sample.x;				// used
	STATE.m_palette_v= anm2_sample.y;
	
	return STATE;
}


#ifdef PARTICLE_WRITE

#define _state_pos		0
#define _state_vel		1
#define	_state_rnd		2
#define _state_rnd2		3
#define _state_rot		4
#define _state_time		5
#define _state_anm		6
#define _state_anm2		7
#define _state_axis		8
#define _state_col		9
#define _state_col2		10
#define _state_max		11

struct s_memexport
{
	float4 m_stream_constant;
	float2 m_stride_offset;
};

BEGIN_REGISTER_GROUP(memexport)
extern s_memexport g_all_memexport[_state_max];
END_REGISTER_GROUP(memexport)

// The including function must define the stride_offset and stream_constant registers.
void write_particle_state(s_particle_state STATE, int index)
{
	static float4 stream_helper= {0, 1, 0, 0};
	float4 export[_state_max];

	// This code basically compiles away, since it's absorbed into the
	// compiler's register mapping.
	export[_state_pos]= float4(STATE.m_position, STATE.m_size);
	export[_state_vel]= float4(STATE.m_velocity, STATE.m_aspect);
	export[_state_rot]= float4(STATE.m_physical_rotation, STATE.m_manual_rotation, 
		STATE.m_animated_frame, STATE.m_manual_frame);
	export[_state_time]= float4(STATE.m_birth_time, STATE.m_inverse_lifespan, STATE.m_age, STATE.m_intensity);
	export[_state_anm]= float4(STATE.m_rotational_velocity, STATE.m_frame_velocity, STATE.m_game_simulation_a, STATE.m_game_simulation_b);
	export[_state_anm2]= float4(STATE.m_black_point, STATE.m_palette_v, 0.0f, 0.0f);
	export[_state_rnd]= float4(STATE.m_random);
	export[_state_rnd2]= float4(STATE.m_random2);
	export[_state_axis]= float4(STATE.m_axis, 0.0f);
	export[_state_col]= float4(STATE.m_color);
	export[_state_col2]= float4(STATE.m_initial_color);
#ifndef PARTICLE_WRITE_DISABLE_FOR_PROFILING
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
#endif	//#ifdef PARTICLE_WRITE

// Match with c_particle_state_list::e_particle_state_input
#define _state_particle_age							0	//_particle_age
#define _state_system_age							1	//_system_age
#define _state_particle_random_seed					2	//_particle_random_seed
#define _state_system_random_seed					3	//_system_random_seed
#define _state_particle_correlation_1				4	//_particle_correlation_1
#define _state_particle_correlation_2				5	//_particle_correlation_2
#define _state_particle_correlation_3				6	//_particle_correlation_3
#define _state_particle_correlation_4				7	//_particle_correlation_4
#define _state_system_correlation_1					8	//_system_correlation_1
#define _state_system_correlation_2					9	//_system_correlation_2
#define _state_particle_emit_time					10	//_particle_emit_time
#define _state_location_lod							11	//_location_lod
#define _state_game_time							12	//_game_time
#define _state_object_a_out							13	//_object_a_out
#define _state_object_b_out							14	//_object_b_out
#define _state_particle_rotation					15	//_particle_rotation
#define _state_location_random_seed_1				16	//_location_random_seed_1
#define _state_particle_distance_from_emitter		17	//_particle_distance_from_emitter
#define _state_game_simulation_a					18	//_particle_simulation_a		// was _state_particle_rotation_dot_eye_forward		//_particle_rotation_dot_eye_forward		--- UNUSED, old halo 2 stuff (###ctchou $TODO what was this for?)
#define _state_game_simulation_b					19	//_particle_simulation_b		// was _state_particle_rotation_dot_eye_left		//_particle_rotation_dot_eye_left
#define _state_particle_velocity					20	//_particle_velocity
#define _state_invalid								21	//_invalid
#define _state_particle_random_seed_5				22	//_particle_random_seed_5
#define _state_particle_random_seed_6				23	//_particle_random_seed_6
#define _state_particle_random_seed_7				24	//_particle_random_seed_7
#define _state_particle_random_seed_8				25	//_particle_random_seed_8
#define _state_system_random_seed_3					26	//_system_random_seed_3
#define _state_system_random_seed_4					27	//_system_random_seed_4
#define _state_total_count							28	//k_total_count

// Match with s_gpu_single_state in c_particle_emitter_gpu::set_shader_update_state()
struct s_gpu_single_state
{
	float m_value;
};
struct s_all_state
{
	s_gpu_single_state m_inputs[_state_total_count];
};
extern s_all_state g_all_state;

float get_state_value(const s_particle_state particle_state, int index)
{
	if (index==_state_particle_age)
	{
		return particle_state.m_age;
	}
	else if (index>= _state_particle_correlation_1 && index <= _state_particle_correlation_4)
	{
		return particle_state.m_random[index-_state_particle_correlation_1];
	}
	else if (index>= _state_particle_random_seed_5 && index <= _state_particle_random_seed_8)
	{
		return particle_state.m_random2[index-_state_particle_random_seed_5];
	}
	else if (index==_state_particle_emit_time)
	{
		return particle_state.m_birth_time;
	}
	else if (index==_state_game_simulation_a)
	{
		return particle_state.m_game_simulation_a;
	}
	else if (index==_state_game_simulation_b)
	{
		return particle_state.m_game_simulation_b;
	}
	else if (index == _state_particle_velocity)
	{
		return length(particle_state.m_velocity) * 0.1f;		// We scale velocity by 0.1 to put it into a more useful range (since functions take input in [0,1])
	}
	else	// a state which is independent of particle
	{
		return g_all_state.m_inputs[index].m_value;
	}
}

#ifndef PARTICLE_NO_PROPERTY_EVALUATE
// This generates multiple inlined calls to evaluate and get_state_value, which are 
// large functions.  If the inlining becomes an issue, we can use the loop 
// trick documented below.
float particle_evaluate(const s_particle_state particle_state, int type)

{
	s_property property= g_all_properties[type];
	if (get_is_constant(property))
	{
		return get_constant_value(property);
	}
	else
	{
		float input= get_state_value(particle_state, get_input_index_green(property));
		float output;
		if (get_function_index_red(property)!= _type_identity)	// hack for ranged, since 0 isn't used
		{
			float interpolate= get_state_value(particle_state, get_input_index_red(property));
			output= evaluate_scalar_ranged(get_function_index_green(property), get_function_index_red(property), input, 
				interpolate);
		}
		else
		{
			output= evaluate_scalar(get_function_index_green(property), input);
		}
		if (get_modifier_index(property)!= _modifier_none)
		{
			float modify_by= get_state_value(particle_state, get_input_index_modifier(property));
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

float3 particle_map_to_color_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_color_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

float2 particle_map_to_vector2d_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_vector2d_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

float3 particle_map_to_vector3d_range(int type, float scalar)
{
	s_property property= g_all_properties[type];
	return map_to_vector3d_range(get_color_index_lo(property), get_color_index_hi(property), scalar);
}

typedef float preevaluated_functions[_index_max];
preevaluated_functions preevaluate_particle_functions(s_particle_state STATE)
{
	// The explicit initializations below are necessary to avoid uninitialized
	// variable errors.  I believe the excess initializations are stripped out.
	float pre_evaluated_scalar[_index_max]= {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
	[loop]
	for (int loop_counter= 0; loop_counter< _index_max; ++loop_counter)
	{
		pre_evaluated_scalar[loop_counter]= particle_evaluate(STATE, loop_counter);
	}

	return pre_evaluated_scalar;
}
#endif	//#ifndef PARTICLE_NO_PROPERTY_EVALUATE

#endif	// #ifndef pc