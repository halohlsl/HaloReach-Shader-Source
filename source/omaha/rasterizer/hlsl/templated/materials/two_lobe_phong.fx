#ifndef _TWO_LOBE_PHONG_FX_
#define _TWO_LOBE_PHONG_FX_

#include "templated\materials\shared_specular.fx"
#include "templated\materials\diffuse_specular.fx"
#include "templated\materials\phong_specular.fx"


/*
two_lobe_phong.fx
Mon, Nov 11, 2005 2:01pm (haochen)
*/

//*****************************************************************************
// Analytical model for point light source only
//*****************************************************************************

float get_material_two_lobe_phong_specular_power(float power_or_roughness)
{
	return power_or_roughness;
}


float3 get_analytical_specular_multiplier_two_lobe_phong_ps(float specular_mask)
{
	return specular_mask * specular_coefficient * analytical_specular_contribution;
}

float3 get_diffuse_multiplier_two_lobe_phong_ps()
{
	return diffuse_coefficient;
}

float4 calc_material_analytic_specular_two_lobe_phong_ps(
	in float3 view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float3 view_reflect_dir,								// view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance)
	in float2 texcoord,	
	in float vertex_n_dot_l,								// original normal dot lighting direction (used for specular masking on far side of object)
	in float3x3 tangent_frame,
	out float4 material_parameters,							// only when use_material_texture is defined
	out float3 normal_specular_blend_albedo_color,			// specular reflectance at normal incidence
	out float3 analytic_specular_radiance,					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	out float3 additional_diffuse_radiance)
{
	float3 final_specular_tint_color;
	float3 surface_normal= tangent_frame[2];

	//figure out the blended power and blended specular tint
	float specular_roughness;
	float specular_power= 0.0f;
	calculate_fresnel(view_dir, normal_dir, diffuse_albedo_color, specular_power, specular_roughness, normal_specular_blend_albedo_color,final_specular_tint_color);
	material_parameters.rgb= float3(specular_coefficient, albedo_specular_tint_blend, environment_map_specular_contribution);
	material_parameters.a= specular_power;
    
    analytic_specular_radiance=analytical_Phong_specular(light_dir,view_reflect_dir,analytical_power)*final_specular_tint_color*light_irradiance;
    additional_diffuse_radiance= 0;
	return float4(final_specular_tint_color,specular_roughness);
}


//*****************************************************************************
// area specular for area light source
//*****************************************************************************


//*****************************************************************************
// the material model
//*****************************************************************************
	
void calc_material_two_lobe_phong_ps(
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
	inout float3 envmap_area_specular_only,
	out float4 specular_radiance,
	inout float3 diffuse_radiance)
{

	float3 analytic_specular_radiance;
	float3 normal_specular_blend_albedo_color;
	float4 material_parameters;
	
	float3 analytical_specular_color;
	float3 additional_diffuse_radiance;
	float4 final_specular_tint_color=calc_material_analytic_specular_two_lobe_phong_ps(
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
		normal_specular_blend_albedo_color,
		analytic_specular_radiance, 
		additional_diffuse_radiance);

	//analytic_specular_radiance*=sh_lighting_coefficients[0].a;

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
			analytical_power,
			simple_light_diffuse_light,
			simple_light_specular_light);
		simple_light_specular_light*= final_specular_tint_color.xyz;
	}
	else
	{
		simple_light_diffuse_light= 0.0f;
		simple_light_specular_light= 0.0f;
	}
	
	float3 area_specular_radiance;
	{
		float4 vmf[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};

        dual_vmf_diffuse_specular_with_fresnel(
			view_dir,
			surface_normal,
			vmf,
			final_specular_tint_color,
			final_specular_tint_color.a,
			area_specular_radiance);
	}
	
	//scaling and masking
	specular_radiance.xyz= specular_mask * material_parameters.r * (
		(simple_light_specular_light + max(analytic_specular_radiance, 0.0f)) * analytical_specular_contribution +
		max(area_specular_radiance * area_specular_contribution, 0.0f));
		
	specular_radiance.w= 0.0f;

	//modulate with prt	
	specular_radiance*= prt_ravi_diff.z;	

	//output for environment stuff
	envmap_area_specular_only= envmap_area_specular_only * final_specular_tint_color.rgb + area_specular_radiance * prt_ravi_diff.z;
	envmap_specular_reflectance_and_roughness.xyz=	material_parameters.b * specular_mask * material_parameters.r;
	envmap_specular_reflectance_and_roughness.w= max(0.01f, 1.01 - material_parameters.a / 200.0f);		// convert specular power to roughness (cheap and bad approximation);

	//do diffuse
	diffuse_radiance= prt_ravi_diff.x * diffuse_radiance;
	diffuse_radiance= (simple_light_diffuse_light + diffuse_radiance) * diffuse_coefficient;
	
}


#endif 