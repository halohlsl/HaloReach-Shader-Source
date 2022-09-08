#include "chud\chud_registers.fx"

LOCAL_SAMPLER_2D(basemap_sampler, 0);

#ifndef pc
LOCAL_SAMPLER_2D(noise_sampler, 2);
#endif // pc

struct chud_output
{
	float4 HPosition	:SV_Position;
	float2 Texcoord		:TEXCOORD0;
	float2 MicroTexcoord:TEXCOORD1;
};

float angle_between_vectors(float3 a, float3 b)
{
	float angle= 0.0f;
	float aa_bb= dot(a, a)*dot(b, b);
	float ab= dot(a, b);

	float c= 2.0*ab*ab/aa_bb - 1.0;

	angle= 0.5*acos(c);

	return angle;
}

float3 rotate_vector_about_axis(
	float3 v,
	float3 n,
	float sine,
	float cosine)
{
	float one_minus_cosine_times_v_dot_n= (1.0 - cosine)*(v.x*n.x + v.y*n.y + v.z*n.z);
	float v_cross_n_i= v.y*n.z - v.z*n.y;
	float v_cross_n_j= v.z*n.x - v.x*n.z;
	float v_cross_n_k= v.x*n.y - v.y*n.x;

	float3 result= float3(
		cosine*v.x + one_minus_cosine_times_v_dot_n*n.x - sine*v_cross_n_i,
		cosine*v.y + one_minus_cosine_times_v_dot_n*n.y - sine*v_cross_n_j,
		cosine*v.z + one_minus_cosine_times_v_dot_n*n.z - sine*v_cross_n_k);

	return result;
}

float3 normals_interpolate(float3 a, float3 b, float t)
{
	float angle= angle_between_vectors(a, b)*t;
	float3 c= normalize(cross(a, b));

	float sine, cosine;

	sincos(angle, sine, cosine);

	return rotate_vector_about_axis(a, c, sine, cosine);
}

float get_noise_basis(float2 input, float4 basis)
{
	float2 origin= basis.xy;
	float2 vec0= basis.zw;
	float2 vec1= basis.wz;
	vec1.x*= -1.0;

	float2 sample= origin + vec0*input.x + vec1*input.y;

	#ifndef pc
	float4 in_noise;
	//float in_noise= tex2D(noise_sampler, input.xy).r;
	asm {
        tfetch2D in_noise, noise_sampler, sample, MinFilter=linear, MagFilter=linear, UseComputedLOD=false, UseRegisterGradients=false
    };
	#else // pc
	float4 in_noise= float4(0,0,0,0);
	#endif // pc

	return in_noise.x;
}

float3 get_noised_input(float3 input)
{
	/*
	float noise_0= get_noise_basis(input, chud_suck_basis_0);
	float noise_1= get_noise_basis(input, chud_suck_basis_1);
	float noise_combined= (noise_0*(1.0f - chud_suck_data.x) + noise_1*(chud_suck_data.x));

	float2 suck_point= chud_suck_data.yz;
	float2 vector_to_suck= input - suck_point;
	float vector_to_suck_length= length(vector_to_suck);
	float suck_radius= chud_suck_data.w;
	float suck_intensity= chud_suck_data2.x;
	float noise_intensity= chud_suck_data2.y;

	float suck_t= max(0, 1.0 - vector_to_suck_length/suck_radius);
	float suck_amount= cos(suck_t*3.141592)*-0.5 + 0.5;

	float3 result= input;

	result.xy= input.xy - vector_to_suck*(suck_amount + noise_combined*noise_intensity);
	//result.z= input.z + (noise_combined-0.5)*chud_suck_vector.w*50.0f;
	result.z= input.z;
	*/
	float3 result= input;

	return result;

}

float2 chud_transform(float3 input)
{
	#ifndef pc
	float3 noised_input= get_noised_input(input);
	#else //pc
	float3 noised_input= input;
	#endif // pc

	input.xy= 2.0*input.xy - 1.0;
	input.y= -input.y;
	float2 input_squared= input.xy*input.xy;
	float2 intermediate= chud_basis_01.xy*input_squared.x*input_squared.y + chud_basis_01.zw*input_squared.x*input.y + chud_basis_23.xy*input_squared.x
					   + chud_basis_23.zw*input.x*input_squared.y         + chud_basis_45.xy*input.x*input.y         + chud_basis_45.zw*input.x
					   + chud_basis_67.xy*input_squared.y				  + chud_basis_67.zw*input.y				 + chud_basis_8.xy;

	float2 result;
	result= float2(
		chud_screen_scale_and_offset.x + chud_screen_scale_and_offset.y + chud_screen_scale_and_offset.y*intermediate.x,
		chud_screen_scale_and_offset.z + chud_screen_scale_and_offset.w + chud_screen_scale_and_offset.w*intermediate.y);


#ifndef IGNORE_SCREENSHOT_TILING
	// handle screenshots
	result.xy= result.xy*chud_screenshot_info.xy + chud_screenshot_info.zw;
#endif // IGNORE_SCREENSHOT_TILING

	// convert to 'true' screen space
	result.x= (result.x - chud_screen_size.x/2.0)/chud_screen_size.x;
	result.y= (-result.y + chud_screen_size.y/2.0)/chud_screen_size.y;

	return result;
}

float2 chud_transform_2d(float3 input)
{
	float2 result= input.xy*10.0/12.0;

	result.x-= 0.5f;
	result.y-= 0.5f;
	result.x+= 1.0/12.0;
	result.y+= 1.0/12.0;

	return result;
}

float3 chud_local_to_virtual(float2 local)
{
    float3 position= float3(local, 0.0);
    position.xyz= position.xyz - chud_widget_offset.xyz;
    position.xy= position.xy*chud_widget_mirror.xy;

    float3 transformed_position;

    transformed_position.x= dot(float4(position, 1.0f), chud_widget_transform1);
    transformed_position.y= dot(float4(position, 1.0f), chud_widget_transform2);
    transformed_position.z= dot(float4(position, 1.0f), chud_widget_transform3);

    return transformed_position;
}

float4 chud_virtual_to_screen(float3 virtual_position)
{
	float3 transformed_position_scaled= float3(
		virtual_position.x/chud_screen_size.z,
		1.0 - virtual_position.y/chud_screen_size.w,
		virtual_position.z);

	return float4(chud_transform(transformed_position_scaled), 0.5, 0.5);
}

float chud_blend(float a, float b, float t)
{
	return a*(1.0 - t) + b*t;
}

float3 chud_blend3(float3 a, float3 b, float t)
{
	return a*(1.0 - t) + b*t;
}

accum_pixel chud_compute_result_pixel(float4 color)
{
	return convert_to_render_target(float4(sqrt(color.rgb), color.a), false, false);
}
