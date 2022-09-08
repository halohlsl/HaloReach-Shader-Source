#ifndef _COOK_TORRANCE_FX_
#define _COOK_TORRANCE_FX_

/*
cook_torrance.fx
Mon, Jul 25, 2005 5:01pm (haochen)
*/

/* NOTICE: all extern parameters and 
   function implementation has been 
   contained in this file */
#include "templated\materials\cook_torrance_core.fx"


float get_material_cook_torrance_specular_power(float power_or_roughness)
{
	return roughness_to_power(power_or_roughness);	
}	

float get_material_cook_torrance_specular_power_scale(float power_or_roughness)
{
	return calc_specular_power_scale(power_or_roughness);
}	

float3 get_analytical_specular_multiplier_cook_torrance_ps(float specular_mask)
{
	return calc_analytical_specular_multiplier(specular_mask);
}

float3 get_diffuse_multiplier_cook_torrance_ps()
{
	return calc_diffuse_multiplier();
}


//*****************************************************************************
// Analytical Cook-Torrance for point light source only
//*****************************************************************************
void calc_material_analytic_specular_cook_torrance_ps(
	in float3 view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float3 view_reflect_dir,								// view_dir reflected about surface normal, in world space
	in float3 L,											// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance)
	in float2 texcoord,
	in float vertex_n_dot_l,								// original normal dot lighting direction (used for specular masking on far side of object)
	in float3x3 tangent_frame,
	out float4 spatially_varying_material_parameters,
	out float3 normal_specular_blend_albedo_color,			// specular reflectance at normal incidence
	out float3 analytic_specular_radiance,
	out float3 additional_diffuse_radiance)
{
	calc_material_analytic_specular(
		view_dir,				
		normal_dir,				
		view_reflect_dir,			
		L,						
		light_irradiance,			
		diffuse_albedo_color,		
		texcoord,
		vertex_n_dot_l,			
		tangent_frame,
		spatially_varying_material_parameters,
		normal_specular_blend_albedo_color,	
		analytic_specular_radiance);

	additional_diffuse_radiance= 0;
}		

//*****************************************************************************
// cook-torrance for area light source in SH space
//*****************************************************************************
void calc_material_cook_torrance_ps(
	in float3 view_dir,						// normalized
	in float3 fragment_to_camera_world,
	in float3 view_normal,					// normalized
	in float3 view_reflect_dir_world,		// normalized
	in float4 sh_lighting_coefficients[4],	//NEW LIGHTMAP: changing to linear
	in float3 view_light_dir,				// normalized
	in float3 light_color,
	in float3 albedo_color,
	in float  specular_mask,
	in float2 texcoord,
	in float4 prt_ravi_diff,
	in float3x3 tangent_frame,				// = {tangent, binormal, normal};
	out float4 envmap_specular_reflectance_and_roughness,
	inout float3 envmap_area_specular_only,
	out float4 specular_radiance,
	inout float3 diffuse_radiance)
{  
#ifdef SHADER_30

	calc_material_full(
		view_dir,		
		fragment_to_camera_world,
		view_normal,	
		view_reflect_dir_world,
		sh_lighting_coefficients,
		view_light_dir,
		light_color,
		albedo_color,
		specular_mask,
		texcoord,
		prt_ravi_diff,
		tangent_frame,				// = {tangent, binormal, normal};
		envmap_specular_reflectance_and_roughness,
		envmap_area_specular_only,
		specular_radiance,
		diffuse_radiance);


#else //!SHADER_30

	diffuse_color= diffuse_in;
	specular_radiance= 0.0f;

	envmap_specular_reflectance_and_roughness.xyz=	environment_map_specular_contribution * specular_mask * specular_coefficient;
	envmap_specular_reflectance_and_roughness.w=	roughness;			// TODO: replace with whatever you use for roughness	

	envmap_area_specular_only= 1.0f;

#endif //SHADER_30
	return;
}

#endif //_COOK_TORRANCE_FX_