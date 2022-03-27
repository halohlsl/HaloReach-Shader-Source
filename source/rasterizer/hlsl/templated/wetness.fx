#include "shared\utilities.fx"

float wet_material_dim_coefficient;
float3 wet_material_dim_tint;
float wet_sheen_reflection_contribution;
float3 wet_sheen_reflection_tint;
float wet_sheen_thickness;
float specular_mask_tweak_weight;
float surface_tilt_tweak_weight;


// ripple maps for rain drop ripples
sampler wet_flood_slope_map;
float4 wet_flood_slope_map_xform;

sampler wet_noise_boundary_map;
float4 wet_noise_boundary_map_xform;


/* -------------- vertex shader wetness computation */
float fetch_per_vertex_wetness_from_texture(
	in int index_of_vertex)
{
	float vertex_wetness= 1;
#ifdef USE_PER_VERTEX_WETNESS_TEXTURE
#ifdef VERTEX_SHADER
#ifdef xenon

#define k_pixel_channel_count 4
	[branch]
	if (vs_boolean_enable_wet_effect)
	{
		[branch]
		if (k_vs_wetness_constants.w > 0)
		{
			const float texture_width= k_vs_wetness_constants.x;
			const float row_vertex_count= texture_width * k_pixel_channel_count;

			const float pixel_index= k_vs_wetness_constants.y + index_of_vertex;	

			float2 texcoord;
			texcoord.y= floor( pixel_index / row_vertex_count );

			const float row_vertex_index= pixel_index - texcoord.y*row_vertex_count;
			texcoord.x= floor( row_vertex_index / k_pixel_channel_count );

			const float channel_index= row_vertex_index - texcoord.x*k_pixel_channel_count;

			float4 wetness_values, wetness_component;
			float4 wetness_component_match= float4(0, 1, 2, 3);          // bytes are 4-byte swapped (each dword is stored in reverse order)
			asm {			
				tfetch2D wetness_values, texcoord, k_vs_sampler_per_vertex_wetness, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, UseComputedLOD= false
				seq	wetness_component, channel_index.xxxx, wetness_component_match		// set the component that matches to one		
			};

			vertex_wetness= dot(wetness_component, wetness_values);	
		}
	}	
	
#endif // xenon
#endif	// VERTEX_SHADER
#endif // USE_PER_VERTEX_WETNESS_TEXTURE
	return vertex_wetness;
}


/* -------------- pixel shader wetness for different shader setting */
#ifndef NO_WETNESS_EFFECT

// disable wetness effect for faraway object
float fade_wetness_by_distance(
	in float distance2)
{
	return saturate(2.0f - distance2*0.0004);	// start fade 50, end fade 100
}

float3 sample_reflect_cubemaps(
	in float3 reflect_dir,	
	in float cubemap_blend_factor)
{	
#ifdef must_be_environment
	float4 reflection_0= texCUBE(dynamic_environment_map_0, reflect_dir); 
	reflection_0.rgb= reflection_0.rgb * reflection_0.rgb * reflection_0.a;
	return reflection_0.rgb;
#else // !must_be_environment
	float4 reflection_0= texCUBE(dynamic_environment_map_0, reflect_dir); 
	float4 reflection_1= texCUBE(dynamic_environment_map_1, reflect_dir); 

	reflection_0.rgb= reflection_0.rgb * reflection_0.rgb * reflection_0.a;
	reflection_1.rgb= reflection_1.rgb * reflection_1.rgb * reflection_1.a;

	float3 reflect_color= lerp(reflection_1.rgb, reflection_0.rgb, cubemap_blend_factor);
	return reflect_color;
#endif // !must_be_environment
}

void calc_noised_per_pixel_wetness(
   in float3 fragment_position,
   in float per_pixel_wetness,
   out float noised_per_pixel_wetness,
   out float noised_per_pixel_reflection)
{	
	float2 noise_texcoord= fragment_position.xy * float2(2.9713f/4.0f, 3.1137f/4.0f);
	const float3 noise_value= tex2D(wet_noise_boundary_map, noise_texcoord);	
	const float noise= dot(noise_value, float3(0.2, -0.4f, 0.2));		
	const float noise_fade= saturate(2.5f - 5.0f * abs(0.5 - per_pixel_wetness));
	float noised_wetness= saturate(per_pixel_wetness + noise * noise_fade);
	noised_per_pixel_wetness= saturate(2.0f*noised_wetness - 1.0f);
	noised_per_pixel_reflection= saturate(3.0f*noised_wetness - 2.0f);		
	//noised_per_pixel_wetness= saturate(2.0f*per_pixel_wetness - 1.0f);
	//noised_per_pixel_reflection= saturate(4.0f*per_pixel_wetness - 3.0f);		

}

float2 calc_splash_slope_from_one_tile(
	in const float display_speed,
	in const float splash_tile_size_with_margin,
	in const float splash_tile_shift_range,
	in const float splash_tile_texcoord_scale,	
	in const float game_time,
	in const float3 fragment_position,	
	in const float4 randomize_noise_direction)
{
	float2 ripple_texcoord;
	ripple_texcoord.xy= fragment_position.xy / splash_tile_size_with_margin;	// hard-coded scale
	ripple_texcoord.xy+= randomize_noise_direction.xy * fragment_position.z;		
	
	float layer_id= game_time * display_speed;
	layer_id+= dot(floor(ripple_texcoord.xy), float2(77.723321, 17.271231));

	float layer_z= frac(layer_id);
	layer_id= floor(layer_id);

	float2 random_xy= randomize_noise_direction.zw * layer_id;
	random_xy= frac(random_xy);		// in range [0, 1]
	random_xy= random_xy*2.0f - 1.0f;	// in range [-1, 1]
	
	float2 final_texcoord;
	final_texcoord= frac(ripple_texcoord);
	final_texcoord-= splash_tile_shift_range*(1 + random_xy);
	final_texcoord= saturate(final_texcoord*splash_tile_texcoord_scale);			

	float2 ripple_normal= tex3D(k_ps_sampler_wet_rain_ripple, float3(saturate(final_texcoord), layer_z)).xy;					
	ripple_normal= ripple_normal*2 -1.0f;	

	// clamp the incorrect zero normal value as precise 0
	// in rgba8 format, we can't represent 0 correctly
	ripple_normal*= saturate(100 * saturate(dot(abs(ripple_normal), 1) - 0.01f));
	
	return ripple_normal;			
}

// apply noise ripple by droplets over sheen
void disturb_sheen_normal_by_droplet(
	in float3 surface_normal, 
	in float2 ripple, 
	inout float3 sheen_normal,
	inout float reflection_enhance_by_ripple)
{
	#define RAIN_INTENSITY					k_ps_wetness_coefficients.w
	#define RIPPLE_SCALE					k_ps_rain_ripple_coefficients.x
	#define RIPPLE_OFFSET					k_ps_rain_ripple_coefficients.y

	float angle_blend_ratio= 5.0 * saturate(surface_normal.z - 0.6f);

	sheen_normal.xy += (ripple.xy * RIPPLE_SCALE + RIPPLE_OFFSET) * angle_blend_ratio;
	reflection_enhance_by_ripple= 1.0 + dot(abs(ripple), 2);
}

void calc_fresnel_effect(
	 in float3 normal_dir,
	 in float3 view_dir,
	 out float reflection_tweak,
	 out float refraction_tweak)
{	
	float fresnel_coeff= saturate(1 - dot(normal_dir, view_dir));
	fresnel_coeff*= fresnel_coeff;
	fresnel_coeff= 0.8f*fresnel_coeff + 0.2f;		
	reflection_tweak= fresnel_coeff;
	refraction_tweak= 2.0f - fresnel_coeff;	
}


float3 calc_final_color(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 sheen_normal,	
	in float global_wetness_control,
	in float global_reflection_control,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{
	float3 out_color;

	//	calc fresnel
	float fresnel_reflection_tweak;
	float fresnel_refraction_tweak;
	calc_fresnel_effect(sheen_normal, view_dir, fresnel_reflection_tweak, fresnel_refraction_tweak);

	// get final dim after considering everything
	float3 material_dim_and_tint=
		saturate(wet_material_dim_tint * wet_material_dim_coefficient * fresnel_refraction_tweak);

	// get materail dim	
	material_dim_and_tint= lerp(1.0f, material_dim_and_tint, global_wetness_control);
	out_color= material_color*material_dim_and_tint;

	//[branch][ifAny]
	//if (global_reflection_control)
	{		
		const float specular_tweak_by_mask= lerp(1.0f, specular_mask, specular_mask_tweak_weight);
		const float final_reflection_contribution= 
			wet_sheen_reflection_contribution *
			global_reflection_control * 
			fresnel_reflection_tweak * 
			specular_tweak_by_mask;	

		// get specular 	
		float3 reflection_dim_and_tint_by_vmf=
					(vmf_lighting_coefficients[1].rgb + vmf_lighting_coefficients[3].rgb);	

		reflection_dim_and_tint_by_vmf+=
					k_ps_analytical_light_intensity * 
					(saturate(dot(k_ps_analytical_light_direction, surface_normal))*0.7 + 0.3) *
					analytical_mask;		

		// consider lightmap shadow
		reflection_dim_and_tint_by_vmf*= 0.15*shadow_mask.a + 0.05;

		// get reflect color
		float3 sheen_reflect_dir= -reflect(view_dir, sheen_normal);		
		float3 sheen_reflect_color= sample_reflect_cubemaps(sheen_reflect_dir, dynamic_environment_blend.w);
		sheen_reflect_color*= wet_sheen_reflection_tint;			
		
		out_color+=
			sheen_reflect_color * 
			reflection_dim_and_tint_by_vmf *
			final_reflection_contribution;	
	}

	return out_color;
}


float3 calc_wetness_simple_ps(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 bump_normal,
	in float3 fragment_to_camera_world,	
	in float per_pixel_wetness,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{
	float3 out_color= material_color;	
	const float distance_to_camera= length(fragment_to_camera_world);
	float k_global_wetness_control= 
		k_ps_wetness_coefficients.x * 
		fade_wetness_by_distance(distance_to_camera) * 
		per_pixel_wetness;

	[branch]
	if (k_global_wetness_control > 0.01f)
	{
		// get final dim after considering everything
		float3 material_dim_and_tint= wet_material_dim_tint * wet_material_dim_coefficient;		
		material_dim_and_tint= lerp(1.0f, material_dim_and_tint, k_global_wetness_control);
		out_color= material_color*material_dim_and_tint;
	}
	
	return out_color;
}


float3 calc_wetness_default_ps(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 bump_normal,
	in float3 fragment_to_camera_world,	
	in float per_pixel_wetness,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{
	return calc_wetness_simple_ps(material_color, view_dir, surface_normal, bump_normal, fragment_to_camera_world, per_pixel_wetness, vmf_lighting_coefficients, analytical_mask, shadow_mask, specular_mask);
}


float3 calc_wetness_ripples_ps(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 bump_normal,
	in float3 fragment_to_camera_world,	
	in float per_pixel_wetness,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{
	float3 out_color= material_color;	

	const float k_game_time= k_ps_wetness_coefficients.y;

	const float distance2_to_camera= dot(fragment_to_camera_world, fragment_to_camera_world);
	float k_global_wetness_control= 
		k_ps_wetness_coefficients.x * 
		fade_wetness_by_distance(distance2_to_camera);

	[branch]
	if (k_global_wetness_control*per_pixel_wetness > 0.01f)
	{
		// noisalized boundary
		const float3 fragment_position= Camera_Position_PS - fragment_to_camera_world;
		float noised_per_pixel_wetness;
		float noised_per_pixel_reflection;

		float tilt_ratio= saturate(surface_tilt_tweak_weight - surface_normal.z);		
		calc_noised_per_pixel_wetness(
			fragment_position, 
			saturate(per_pixel_wetness - tilt_ratio),
			noised_per_pixel_wetness, noised_per_pixel_reflection);
		

		float k_global_reflection_control= 
			k_global_wetness_control * noised_per_pixel_reflection;	
		//k_global_reflection_control/= max(1.0f, distance2_to_camera*0.01); // fade out specular in 10

		k_global_wetness_control= k_global_wetness_control * noised_per_pixel_wetness;		

		//[branch][ifAny]
		//if (k_global_wetness_control > 0.01f)
		{
			float3 sheen_normal= lerp(bump_normal, surface_normal, wet_sheen_thickness);			

			// apply droplet ripples
			float reflection_enhance_by_ripple;
			disturb_sheen_normal_by_droplet(
				surface_normal, shadow_mask.gb,
				sheen_normal,
				reflection_enhance_by_ripple);

			sheen_normal= normalize(sheen_normal);

			// get reflect color
			out_color= calc_final_color(
				material_color, view_dir, 
				surface_normal, sheen_normal, 
				k_global_wetness_control, 
				k_global_reflection_control*reflection_enhance_by_ripple,
				vmf_lighting_coefficients, 
				analytical_mask, 
				shadow_mask,
				specular_mask);
		}
	}	
	return out_color;
}


void disturb_sheen_normal_by_flood(
	in float distance2_to_camera,
    in float3 surface_normal,
	in float game_time,
	in float3 fragment_position,
	in float global_reflection_control,
	inout float3 sheen_normal)
{	
	float3 ripple_texcoord;
	ripple_texcoord.xy= fragment_position.xy*float2(0.72721, 0.335793) - float2(0.0795793, 0.057721)*game_time;
	ripple_texcoord.z= game_time * 0.67239;
	ripple_texcoord.xy*= 3.1717;

	float3 ripple_normal_0= tex3Dlod(wet_flood_slope_map, float4(ripple_texcoord, 1)).xyz;	
	ripple_normal_0= ripple_normal_0 * 2.0f - 1.0f;		

	ripple_texcoord.xy= fragment_position.xy*float2(0.62721, 0.435793) + float2(0.0595793, 0.052721)*game_time;
	ripple_texcoord.z= game_time * 0.79239;
	ripple_texcoord.xy*= 3.51773;

	float3 ripple_normal_1= tex3Dlod(wet_flood_slope_map, float4(ripple_texcoord, 1)).xyz;	
	ripple_normal_1= ripple_normal_1 * 2.0f - 1.0f;

	float3 ripple_normal= ripple_normal_0 * ripple_normal_1;
	sheen_normal.xy+= 
		ripple_normal.xy * 
		saturate(2.0f - sqrt(distance2_to_camera)*0.4f) * 
		saturate(surface_normal.z*2.0f - 1.0f) *
		global_reflection_control;	// disable wave near the dry area	
}


float3 calc_wetness_flood_ps(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 bump_normal,
	in float3 fragment_to_camera_world,	
	in float per_pixel_wetness,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{
	float3 out_color= material_color;	

	const float k_game_time= k_ps_wetness_coefficients.y;

	const float distance2_to_camera= dot(fragment_to_camera_world, fragment_to_camera_world);
	float k_global_wetness_control= 
		k_ps_wetness_coefficients.x * 
		fade_wetness_by_distance(distance2_to_camera);

	[branch][ifAny]
	if (k_global_wetness_control*per_pixel_wetness > 0.01f)
	{
		// noisalized boundary
		const float3 fragment_position= Camera_Position_PS - fragment_to_camera_world;
		float noised_per_pixel_wetness;
		float noised_per_pixel_reflection;

		float tilt_ratio= saturate(surface_tilt_tweak_weight - surface_normal.z);		
		calc_noised_per_pixel_wetness(
			fragment_position, 
			saturate(per_pixel_wetness - tilt_ratio),
			noised_per_pixel_wetness, noised_per_pixel_reflection);
		

		float k_global_reflection_control= 
			k_global_wetness_control * noised_per_pixel_reflection;	
		//k_global_reflection_control/= max(1.0f, distance2_to_camera*0.01); // fade out specular in 10

		k_global_wetness_control= k_global_wetness_control * noised_per_pixel_wetness;		

		//[branch][ifAny]
		//if (k_global_wetness_control > 0.01f)
		{
			float3 sheen_normal= lerp(bump_normal, surface_normal, wet_sheen_thickness);			

			// apply flood slope		
			disturb_sheen_normal_by_flood(
				distance2_to_camera,
				surface_normal, k_game_time, fragment_position, 
				k_global_reflection_control,
				sheen_normal);

			// apply droplet ripples									
			float reflection_enhance_by_ripple;
			disturb_sheen_normal_by_droplet(
				surface_normal, shadow_mask.gb,
				sheen_normal,
				reflection_enhance_by_ripple);						

			sheen_normal= normalize(sheen_normal);

			// get reflect color
			out_color= calc_final_color(
				material_color, view_dir, 
				surface_normal, sheen_normal, 
				k_global_wetness_control, 
				k_global_reflection_control*reflection_enhance_by_ripple,
				vmf_lighting_coefficients, 
				analytical_mask, 
				shadow_mask,
				specular_mask);
		}
	}	
	
	return out_color;


	return out_color;
}


float3 calc_wetness_proof_ps(
	in float3 material_color, 
	in float3 view_dir, 
	in float3 surface_normal,
	in float3 bump_normal,
	in float3 fragment_to_camera_world,	
	in float per_pixel_wetness,
	in float4 vmf_lighting_coefficients[4], 
	in float analytical_mask, 
	in float4 shadow_mask,
	in float specular_mask)
{	
	return material_color;
}


#endif //NO_WETNESS_EFFECT
