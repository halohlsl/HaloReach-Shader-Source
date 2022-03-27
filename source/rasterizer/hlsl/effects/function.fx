/*
FUNCTION.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
12/8/2005 4:38:18 PM (davcook)
	
HLSL inclusion file for evaluating functions a la function_definitions.cpp	
*/

#include "effects\register_group.fx"
#include "effects\function_utilities.fx"

#define _register_group_functions	1
#define _register_group_colors		2

#define _maximum_overall_function_count 25
#define _maximum_overall_color_count 8
#define _maximum_sub_function_count 4	//k_maximum_function_count

#define _periodic_function_one									0
#define _periodic_function_zero									1
#define _periodic_function_cosine								2
#define _periodic_function_cosine_with_random_period			3
#define _periodic_function_diagonal_wave						4
#define _periodic_function_diagonal_wave_with_random_period		5
#define _periodic_function_slide								6
#define _periodic_function_slide_with_random_period				7
#define _periodic_function_noise								8
#define _periodic_function_jitter								9
#define _periodic_function_wander								10
#define _periodic_function_spark								11
#define _periodic_function_max									12

#define _transition_function_linear		0
#define _transition_function_early		1 // x^0.5
#define _transition_function_very_early	2 // x^0.25
#define _transition_function_late		3 // x^2.0
#define _transition_function_very_late	4 // x^4.0
#define _transition_function_cosine		5 // accelerates in and out
#define _transition_function_one		6
#define _transition_function_zero		7
#define _transition_function_max		8

#define _type_identity 0			//_function_type_identity,			
#define _type_constant 1			//_function_type_constant,			
#define _type_transition 2			//_function_type_transition,			
#define _type_periodic 3			//_function_type_periodic,			
#define _type_linear 4				//_function_type_linear,				
#define _type_linear_key 5			//_function_type_linear_key,			
#define _type_multi_linear_key 6	//_function_type_multi_linear_key,	
#define _type_spline 7				//_function_type_spline,				
#define _type_multi_spline 8		//_function_type_multi_spline,		
#define _type_exponent 9			//_function_type_exponent,
#define _type_spline2 10			//_function_type_spline2,

#define _output_clamped_bit 2		//_function_flag_clamped_bit
#define _output_exclusion_bit 3		//_function_flag_exclusion_bit

// Max size of type-specific function innards
struct s_innards
{
	float4 m_unused1;
	float4 m_unused2;
};

struct s_function_definition
{
	float4 m_type_domain_max_range_min_range_max;
	float4 m_flags_exclusion_min_exclusion_max;
	
#define m_type			m_type_domain_max_range_min_range_max.x	
#define m_domain_max	m_type_domain_max_range_min_range_max.y	
#define m_range_min		m_type_domain_max_range_min_range_max.z	
#define m_range_max		m_type_domain_max_range_min_range_max.w	
#define m_flags			m_flags_exclusion_min_exclusion_max.x
#define m_exclusion_min	m_flags_exclusion_min_exclusion_max.y
#define m_exclusion_max	m_flags_exclusion_min_exclusion_max.z
	
	s_innards m_innards;	// cast this to appropriate type
};

BEGIN_REGISTER_GROUP(functions)
extern s_function_definition g_all_functions[_maximum_overall_function_count];
END_REGISTER_GROUP(functions)

BEGIN_REGISTER_GROUP(colors)
extern float4 g_all_colors[_maximum_overall_color_count];
END_REGISTER_GROUP(colors)

float sqr(float input)
{
	return input*input;
}

float evaluate_transition_internal(int transition_type, float input)
{
	float output;							
	if (transition_type==_transition_function_linear)
	{
		output= input;
	}
	else if (transition_type==_transition_function_early)
	{
		output= sqrt(input);
	}
	else if (transition_type==_transition_function_very_early)
	{
		output= sqrt(sqrt(input));
	}
	else if (transition_type==_transition_function_late)
	{
		output= sqr(input);
	}
	else if (transition_type==_transition_function_very_late)
	{
		output= sqr(sqr(input));
	}
	else if (transition_type==_transition_function_cosine)
	{
		output= cos(_2pi*(input+1));
	}
	else if (transition_type==_transition_function_one)
	{
		output= 1;
	}
	else //if (transition_type==_transition_function_zero)
	{
		output= 0;
	}
	return output;
}
	
float evaluate_periodic_internal(int periodic_type, float input)
{
	float output;							
	if (periodic_type==_periodic_function_one)
	{
		output= 1;
	}
	else if (periodic_type==_periodic_function_zero)
	{
		output= 0;
	}
	else if (periodic_type==_periodic_function_cosine)
	{
		output= 0.5f*(cos(_2pi*input)+1);
	}
	else if (periodic_type==_periodic_function_cosine_with_random_period)
	{
		output= 0.5f*(cos(_2pi*input)+1);//###davcook $TODO not yet implemented
	}
	else if (periodic_type==_periodic_function_diagonal_wave)
	{
		output= (input<0.5)?(2*input):(2-2*input);
	}
	else if (periodic_type==_periodic_function_diagonal_wave_with_random_period)
	{
		output= (input<0.5)?(2*input):(2-2*input);//###davcook $TODO not yet implemented
	}
	else if (periodic_type==_periodic_function_slide)
	{
		output= input;
	}
	else if (periodic_type==_periodic_function_slide_with_random_period)
	{
		output= input;//###davcook $TODO not yet implemented
	}
	else if (periodic_type==_periodic_function_noise)
	{
		output= frac(pow(2,input)*10000);	// just a guess for now
	}
	else if (periodic_type==_periodic_function_jitter)
	{
		output= 0.5f*(cos(_2pi*input/4.f)*sin(_2pi*input/2.f) + cos(_2pi*input/7.f)*cos(4.f*_2pi*input) +
					sin(_2pi*input/4.f)*cos(7.f*_2pi*input))+1;
	}
	else if (periodic_type==_periodic_function_wander)
	{
		output= 0.5f*(cos(_2pi*input)*sin(_2pi*input/2.f) + 0.5f*cos(_2pi*input/7.f)*cos(4.f*_2pi*input) +
					0.5f*sin(_2pi*input/4.f)*cos(7.f*_2pi*input))+1;
	}
	else //if (periodic_type==_periodic_function_spark)
	{
		output= input;//###davcook $TODO not yet implemented
	}
	return output;
}

typedef s_innards s_innards_identity;
float evaluate_identity(s_innards base_innards, float input)
{
	s_innards_identity innards= base_innards;
	return input;
}

struct s_innards_constant
{
	float4 m_value_;
	float4 m_unused;
};
float evaluate_constant(s_innards base_innards, float input)
{
#define m_value	m_value_.x	
	s_innards_constant innards= base_innards;
	return innards.m_value;
#undef m_value
}

struct s_innards_transition
{
	float4 m_function_index_;
	float4 m_amplitude_min_amplitude_max;
};
float evaluate_transition(s_innards base_innards, float input)
{
#define m_function_index	m_function_index_.x	
#define m_amplitude_min		m_amplitude_min_amplitude_max.x	
#define m_amplitude_max		m_amplitude_min_amplitude_max.y	

	s_innards_transition innards= base_innards;
	return evaluate_transition_internal(innards.m_function_index, input)
		*(innards.m_amplitude_max-innards.m_amplitude_min)
		+innards.m_amplitude_min;
	
#undef m_function_index
#undef m_amplitude_min
#undef m_amplitude_max
}

struct s_innards_periodic
{
	float4 m_function_index_;
	float4 m_frequency_phase_amplitude_min_amplitude_max;
};
float evaluate_periodic(s_innards base_innards, float input)
{
#define m_function_index	m_function_index_.x	
#define m_frequency			m_frequency_phase_amplitude_min_amplitude_max.x	
#define m_phase				m_frequency_phase_amplitude_min_amplitude_max.y	
#define m_amplitude_min		m_frequency_phase_amplitude_min_amplitude_max.z	
#define m_amplitude_max		m_frequency_phase_amplitude_min_amplitude_max.w	

	s_innards_periodic innards= base_innards;
	float modified_input= frac(input*innards.m_frequency+innards.m_phase);
	return evaluate_periodic_internal(innards.m_function_index, modified_input)
		*(innards.m_amplitude_max-innards.m_amplitude_min)
		+innards.m_amplitude_min;
	
#undef m_function_index
#undef m_frequency	
#undef m_phase
#undef m_amplitude_min
#undef m_amplitude_max
}

struct s_innards_linear
{
	float4 m_slope_offset;
	float4 m_unused;
};
float evaluate_linear(s_innards base_innards, float input)
{
#define m_slope		m_slope_offset.x	
#define m_offset	m_slope_offset.y	

	s_innards_linear innards= base_innards;
	return innards.m_slope*input + innards.m_offset;
	
#undef m_slope	
#undef m_offset	
}

struct s_innards_spline
{
	float4 m_basis_elements;
	float4 m_unused;
};
float evaluate_spline(s_innards base_innards, float input)
{
	s_innards_spline innards= base_innards;
	float4 monomials= float4((float3)input, 1.0f);
	monomials.x *= monomials.y *= monomials.z;
	return dot(innards.m_basis_elements, monomials);
}

struct s_innards_exponent
{
	float4 m_amplitude_min_amplitude_max_exponent;
	float4 m_unused;

};
float evaluate_exponent(s_innards base_innards, float input)
{
#define m_amplitude_min	m_amplitude_min_amplitude_max_exponent.x	
#define m_amplitude_max	m_amplitude_min_amplitude_max_exponent.y	
#define m_exponent		m_amplitude_min_amplitude_max_exponent.z	

	s_innards_exponent innards= base_innards;
	return pow(input, innards.m_exponent)*(innards.m_amplitude_max-innards.m_amplitude_min)
		+innards.m_amplitude_min;
	
#undef m_amplitude_min	
#undef m_amplitude_max	
#undef m_exponent	
}


struct s_innards_spline2
{
	float4 m_basis_elements;
	float4 m_left_x_width_bias;
};
float evaluate_spline2(s_innards base_innards, float input)
{
#define m_left_x	innards.m_left_x_width_bias.x	
#define m_width		innards.m_left_x_width_bias.y	
#define m_bias		innards.m_left_x_width_bias.z	

	s_innards_spline2 innards= base_innards;

	input= sign(m_bias) * pow(abs((input - m_left_x) / m_width), m_bias);
	
	float4 monomials= float4((float3)input, 1.0f);
	monomials.x *= monomials.y *= monomials.z;
	return dot(innards.m_basis_elements, monomials);
	
#undef m_left_x
#undef m_width
#undef m_bias
}

float evaluate_single(int index, float input)
{
	float output;
	s_function_definition fn= g_all_functions[index];
	if (fn.m_type==_type_identity)
	{
		output= evaluate_identity(fn.m_innards, input);
	}
	else if (fn.m_type==_type_constant)
	{
		output= evaluate_constant(fn.m_innards, input);
	}
	else if (fn.m_type==_type_periodic)
	{
		output= evaluate_periodic(fn.m_innards, input);
	}
	else if (fn.m_type==_type_transition)
	{
		output= evaluate_transition(fn.m_innards, input);
	}
	else if (fn.m_type==_type_linear)
	{
		output= evaluate_linear(fn.m_innards, input);
	}
	else if (fn.m_type==_type_spline)
	{
		output= evaluate_spline(fn.m_innards, input);
	}
	else if (fn.m_type==_type_exponent)
	{
		output= evaluate_exponent(fn.m_innards, input);
	}
	else //if (fn.m_type==_type_spline2)
	{
		output= evaluate_spline2(fn.m_innards, input);
	}
	//else
	//{
	//	output= 0.0f;
	//}
	return output;
}

float modify_output(int index, float output)
{
	s_function_definition fn= g_all_functions[index];
	if (TEST_BIT(fn.m_flags, _output_exclusion_bit))
	{
		if (output>fn.m_exclusion_min)
		{
			output+= fn.m_exclusion_max-fn.m_exclusion_min;
		}
	}
	if (TEST_BIT(fn.m_flags, _output_clamped_bit))
	{
		output= saturate(output);
	}
	return output;
}

float evaluate(int index, float input)
{
	// The HLSL compiler doesn't seem to allow dynamic 'for' loops.
	input= max(0.0f, input);
	int real_index= index;
	bool found= false;
	for(int sub_index= 0; sub_index< _maximum_sub_function_count; ++sub_index)
	{
		if (!found && input<= g_all_functions[index+sub_index].m_domain_max)
		{
			real_index= index+sub_index;
			found= true;
		}
	}
	return modify_output(index, evaluate_single(real_index, input));
}

float map_to_scalar_range(int index, float intermediate)
{
	s_function_definition fn= g_all_functions[index];
	return lerp(fn.m_range_min, fn.m_range_max, intermediate);
}

float evaluate_scalar(int index, float input)
{
	return map_to_scalar_range(index, evaluate(index, input));
}

float find_containing_interval(int cindex_min, int cindex_max, float intermediate, out int cindex_lo, out int cindex_hi)
{
	int num_intervals= cindex_max - cindex_min;
	float entry_float= intermediate * num_intervals * _1_minus_epsilon;
	int which_interval= floor(saturate(intermediate) * num_intervals * _1_minus_epsilon);	// avoid overflow
	cindex_lo= cindex_min + which_interval;
	cindex_hi= cindex_lo + 1;
	return entry_float - which_interval;
}

float3 map_to_color_range(int cindex_min, int cindex_max, float intermediate)
{
	int cindex_lo, cindex_hi;
	float interp= find_containing_interval(cindex_min, cindex_max, intermediate, cindex_lo, cindex_hi);
	
	return lerp(g_all_colors[cindex_lo], g_all_colors[cindex_hi], interp);
}

float3 evaluate_color(int index, int cindex_min, int cindex_max, float input)
{
	return map_to_color_range(cindex_min, cindex_max, evaluate(index, input));
}

float2 map_to_point2d_range(int cindex_min, int cindex_max, float intermediate)
{
	int cindex_lo, cindex_hi;
	float interp= find_containing_interval(cindex_min, cindex_max, intermediate, cindex_lo, cindex_hi);
	
	return lerp(g_all_colors[cindex_lo], g_all_colors[cindex_hi], interp);
}

float2 evaluate_point2d(int index, int cindex_min, int cindex_max, float input)
{
	return map_to_point2d_range(cindex_min, cindex_max, evaluate(index, input));
}

float3 map_to_point3d_range(int cindex_min, int cindex_max, float intermediate)
{
	int cindex_lo, cindex_hi;
	float interp= find_containing_interval(cindex_min, cindex_max, intermediate, cindex_lo, cindex_hi);
	
	return lerp(g_all_colors[cindex_lo], g_all_colors[cindex_hi], interp);
}

float3 evaluate_point3d(int index, int cindex_min, int cindex_max, float input)
{
	return map_to_point3d_range(cindex_min, cindex_max, evaluate(index, input));
}

float3 map_to_vector3d_range(int cindex_min, int cindex_max, float intermediate)
{
	int cindex_lo, cindex_hi;
	float interp= find_containing_interval(cindex_min, cindex_max, intermediate, cindex_lo, cindex_hi);

/*	
	// These can all be precomputed...
	float cos_angle= dot(normalize(g_all_colors[cindex_lo]), normalize(g_all_colors[cindex_hi]));
	cos_angle= (cos_angle>=_1_minus_epsilon) ? _1_minus_epsilon : cos_angle;	// handle parallel vectors
	float sin_angle= sqrt(1.0f-sqr(cos_angle));
	float angle= acos(cos_angle);
	
	// Interpolation of two unit directions p0 and p1 separated by angle a:
	//   p(t) = [sin((1-t)a)*p0 + sin(ta)*p1]/sin(a)
	// For non-unit directions, gives uniform rotation and slightly non-linear expansion.
	return (sin((1.0f-interp)*angle)*g_all_colors[cindex_lo] + sin(interp*angle)*g_all_colors[cindex_hi]) / 
		sin_angle;
*/
//	float3 lerp_amount= {interp, interp, interp};
	return lerp(g_all_colors[cindex_lo], g_all_colors[cindex_hi], interp);
}

float3 evaluate_vector3d(int index, int cindex_min, int cindex_max, float input)
{
	return map_to_vector3d_range(cindex_min, cindex_max, evaluate(index, input));
}

float2 map_to_vector2d_range(int cindex_min, int cindex_max, float intermediate)
{
	int cindex_lo, cindex_hi;
	float interp= find_containing_interval(cindex_min, cindex_max, intermediate, cindex_lo, cindex_hi);
	
	// These can all be precomputed...
	float cos_angle= dot(normalize(g_all_colors[cindex_lo]), normalize(g_all_colors[cindex_hi]));
	cos_angle= (cos_angle>=_1_minus_epsilon) ? _1_minus_epsilon : cos_angle;	// handle parallel vectors
	float sin_angle= sqrt(1.0f-sqr(cos_angle));
	float angle= acos(cos_angle);
	
	// Interpolation of two unit directions p0 and p1 separated by angle a:
	//   p(t) = [sin((1-t)a)*p0 + sin(ta)*p1]/sin(a)
	// For non-unit directions, gives uniform rotation and slightly non-linear expansion.
	return (sin((1.0f-interp)*angle)*g_all_colors[cindex_lo] + sin(interp*angle)*g_all_colors[cindex_hi]) / 
		sin_angle;
}

float2 evaluate_vector2d(int index, int cindex_min, int cindex_max, float input)
{
	return map_to_vector2d_range(cindex_min, cindex_max, evaluate(index, input));
}

float evaluate_scalar_ranged(int index1, 
	int index2, 
	float input, 
	float range_input)
{
	return map_to_scalar_range(index1, 
		lerp(evaluate(index1, input), evaluate(index2, input), range_input));
}

float3 evaluate_color_ranged(int index1, 
	int index2, 
	int cindex_min, 
	int cindex_max, 
	float input, 
	float range_input)
{
	return map_to_color_range(cindex_min, cindex_max, 
		lerp(evaluate(index1, input), evaluate(index2, input), range_input));
}

float3 evaluate_vector3d_ranged(int index1, 
	int index2, 
	int cindex_min, 
	int cindex_max, 
	float input, 
	float range_input)
{
	return map_to_vector3d_range(cindex_min, cindex_max, 
		lerp(evaluate(index1, input), evaluate(index2, input), range_input));
}

float2 evaluate_vector2d_ranged(int index1, 
	int index2, 
	int cindex_min, 
	int cindex_max, 
	float input, 
	float range_input)
{
	return map_to_vector2d_range(cindex_min, cindex_max, 
		lerp(evaluate(index1, input), evaluate(index2, input), range_input));
}

#undef m_type			
#undef m_domain_max	
#undef m_range_min		
#undef m_range_max		
#undef m_flags			
#undef m_exclusion_min	
#undef m_exclusion_max	
	

