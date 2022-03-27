//#line 2 "source\rasterizer\hlsl\explicit\cui_directional_blur.hlsl"

#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : COLOR
{
	// don't use the cui_tex2D function, we want to correct the color ourselves
	float4 color= tex2D(source_sampler0, IN.texcoord);

	float2 texcoord= IN.texcoord;

	float4 blurred_color= 0;
	float4 size= k_cui_pixel_shader_pixel_size;
	
	float dx = 1.0f/size.x;
	float dy = 1.0f/size.y;

	const static int sample_count= 19;
	const static float distance_scale= 2;

	const float normal_dist[sample_count] = {
		0.004499061, 0.008843068, 0.016051322, 0.026906797, 0.041655411, 0.059559622, 0.078652814, 0.095932756, 
		0.108072708, 0.119652882, 0.108072708, 0.095932756, 0.078652814, 0.059559622, 0.041655411, 0.026906797, 
		0.016051322, 0.008843068, 0.004499061
	};
	
	for (int i = 0; i < sample_count; i++)
	{
		float offset = i - (sample_count-1)/2;
		float2 sample_location= float2(dx*offset*k_cui_pixel_shader_scalar1*distance_scale, dy*offset*k_cui_pixel_shader_scalar2*distance_scale);
		
		// don't use the cui_tex2D function, we want to correct the color ourselves
		float4 blur_sample= tex2D(source_sampler0, IN.texcoord + sample_location);
		
		blurred_color += blur_sample * normal_dist[i];
	}

	color= color*(1-k_cui_pixel_shader_scalar0) + blurred_color*k_cui_pixel_shader_scalar0;

	float4 transform = k_cui_sampler0_transform;

	color.rgb *= max(color.a, transform.z);
	color.a= color.a * transform.x + transform.y;
	
 	color = cui_tint(color, cui_linear_to_gamma2(k_cui_pixel_shader_tint));

 	return color*scale;
}
