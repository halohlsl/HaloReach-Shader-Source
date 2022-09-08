#ifndef _CUSTOM_SPECULAR_FX_
#define _CUSTOM_SPECULAR_FX_


//****************************************************************************
// custom specular
//****************************************************************************

PARAM_SAMPLER_2D(specular_lobe);						// specular power, tint	(indexed by direction towards sun, and material map)
PARAM_SAMPLER_2D(glancing_falloff);						// fresnel curve
PARAM_SAMPLER_2D(material_map);							// material map --
PARAM(float4, material_map_xform);						//


//*****************************************************************************
// Analytical model for point light source only
//*****************************************************************************
float get_material_custom_specular_specular_power(float power_or_roughness)
{
	return power_or_roughness;
}

float3 get_analytical_specular_multiplier_custom_specular_ps(float specular_mask)
{
	return specular_mask * specular_coefficient * analytical_specular_contribution;
}

float3 get_diffuse_multiplier_custom_specular_ps()
{
	return diffuse_coefficient;
}

float3 calc_material_analytic_specular_custom_specular_ps(
	in float3 view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float3 view_reflect_dir,								// view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance)
	in float2 texcoord,
	in float vertex_n_dot_l,
	in float3x3 tangent_frame,
	out float4 spatially_varying_material_parameters,
	out float3 normal_specular_blend_albedo_color,			// specular reflectance at normal incidence
	out float3 analytic_specular_radiance,					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	out float3 additional_diffuse_radiance)
{
    float3 final_specular_color;
	float specular_power=	50.0f;
    float n_dot_v = dot(normal_dir, view_dir);
    final_specular_color=	sample1D(glancing_falloff, n_dot_v).rgb;

	float3 surface_normal= tangent_frame[2];
	float albedo_blend=	0.0f;

    // the following parameters can be supplied in the material texture
    // r: specular coefficient
    // g: albedo blend
    // b: environment contribution
    // a: roughless
	spatially_varying_material_parameters=	float4(specular_coefficient, albedo_blend, environment_map_specular_contribution, specular_power);

	// half-angle formula
	float3 half_dir=	normalize(view_dir + light_dir);
	float h_dot_n=		saturate(dot(half_dir, normal_dir));

	float material_sample=		sample2D(material_map, transform_texcoord(texcoord, material_map_xform)).g;

	float4 lobe_sample=	sample2D(specular_lobe, float2(h_dot_n, material_sample));

	analytic_specular_radiance= light_irradiance * final_specular_color * lobe_sample.rgb * lobe_sample.rgb;
	normal_specular_blend_albedo_color= float3(1.0f, 1.0f, 1.0f);		// specular_tint

	additional_diffuse_radiance= 0;
	return final_specular_color;
}


//*****************************************************************************
// the material model
//*****************************************************************************

void calc_material_custom_specular_ps(
	in float3 view_dir,
	in float3 fragment_to_camera_world,
	in float3 surface_normal,
	in float3 view_reflect_dir,
	in float4 sh_lighting_coefficients[4],
	in float3 analytical_light_dir,
	in float3 analytical_light_intensity,
	in float3 diffuse_reflectance,
	in float  specular_mask,
	in float2 texcoord,
	in float4 prt_ravi_diff,
	in float3x3 tangent_frame,				// = {tangent, binormal, normal};
	out float4 envmap_specular_reflectance_and_roughness,
	out float3 envmap_area_specular_only,
	out float4 specular_color,
	inout float3 diffuse_radiance)
{
	float3 specular_fresnel_color;
	float3 specular_albedo_color;
	float4 material_parameters;
	float3 additional_diffuse_radiance;

	float3 final_specular_color=calc_material_analytic_specular_custom_specular_ps(
		view_dir,
		surface_normal,
		view_reflect_dir,
		analytical_light_dir,
		analytical_light_intensity,
		diffuse_reflectance,
		texcoord,
		prt_ravi_diff.w,
		tangent_frame,
		material_parameters,
		specular_fresnel_color,
		specular_albedo_color,
		additional_diffuse_radiance);

/*
	// calculate simple dynamic lights
	float3 simple_light_diffuse_light;//= 0.0f;
	float3 simple_light_specular_light;//= 0.0f;

	if (!no_dynamic_lights)
	{
		float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
		calc_simple_lights_analytical(
			fragment_position_world,
			surface_normal,
	//		fragment_to_camera_world,
			view_reflect_dir,												// view direction = fragment to camera,   reflected around fragment normal
			material_parameters.a,
			simple_light_diffuse_light,
			simple_light_specular_light);
	}
	else
	{
		simple_light_diffuse_light= 0.0f;
		simple_light_specular_light= 0.0f;
	}
*/

/*
	float3 area_specular_radiance;
	if (order3_area_specular)
	{
		calculate_area_specular_phong_order_3(
			view_reflect_dir,
			sh_lighting_coefficients,
			material_parameters.a,
			specular_fresnel_color,
			area_specular_radiance);
	}
	else
	{
		float4 temp[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};

		calculate_area_specular_phong_order_2(
			view_reflect_dir,
			temp,
			material_parameters.a,
			specular_fresnel_color,
			area_specular_radiance);
	}
*/

	//scaling and masking
//	specular_color.xyz= specular_mask * material_parameters.r * (
//		(simple_light_specular_light + max(final_specular_color, 0.0f)) * analytical_specular_contribution +
//		max(area_specular_radiance * area_specular_contribution, 0.0f));

	specular_color.xyz=	specular_mask * (final_specular_color * material_parameters.r);
	specular_color.w= 0.0f;

	//modulate with prt
	specular_color*= prt_ravi_diff.z;

	//output for environment stuff
	envmap_area_specular_only= prt_ravi_diff.z;		// area_specular_radiance *
	envmap_specular_reflectance_and_roughness.xyz=	specular_fresnel_color * specular_mask * material_parameters.b * material_parameters.r;
	envmap_specular_reflectance_and_roughness.w=	0.0f;					// max(0.01f, 1.01 - material_parameters.a / 200.0f);		// convert specular power to roughness (cheap and bad approximation);

	//do diffuse
	//float3 diffuse_part= ravi_order_3(surface_normal, sh_lighting_coefficients);
	diffuse_radiance= prt_ravi_diff.x * diffuse_radiance;
//	diffuse_radiance= (simple_light_diffuse_light + diffuse_radiance) * diffuse_coefficient;
	diffuse_radiance= diffuse_radiance * diffuse_coefficient;
}


#endif