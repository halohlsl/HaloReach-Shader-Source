#ifndef _ORGANISM_MATERIAL_FX_
#define _ORGANISM_MATERIAL_FX_

/*
organism.fx
Wed, Apr 4, 2007 2:01pm (xwan)
It's a totally hack of sub-translucent materials, but I bet it works.
*/

//****************************************************************************
// Organism material model parameters
//****************************************************************************

/* NOTICE: all extern parameters and 
   function implementation which are shared 
   with cook-torrance has been contained in this file */
#include "templated\materials\cook_torrance_core.fx"

// rim effects
float3 rim_tint;
float rim_power;
float rim_width;
float rim_maps_transition_ratio;

// subsurface
float3 subsurface_tint;
float subsurface_propagation_bias;
float subsurface_normal_detail;
sampler subsurface_map;

#ifdef pc
	#define FORCE_BRANCH
#else
	#define FORCE_BRANCH	[branch]
#endif


//*****************************************************************************
// the material model
//*****************************************************************************
	
void calc_material_organism_ps(
	in float3 view_dir,
	in float3 fragment_to_camera_world,
	in float3 bump_normal,
	in float3 view_reflect_by_bump_dir,
	in float4 sh_lighting_coefficients[4],
	in float3 analytical_light_dir,
	in float3 analytical_light_intensity,
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
	calc_material_full(
		view_dir,		
		fragment_to_camera_world,
		bump_normal,	
		view_reflect_by_bump_dir,
		sh_lighting_coefficients,
		analytical_light_dir,
		analytical_light_intensity,
		albedo_color,
		specular_mask,
		texcoord,
		prt_ravi_diff,
		tangent_frame,				// = {tangent, binormal, normal};
		envmap_specular_reflectance_and_roughness,
		envmap_area_specular_only,
		specular_radiance,
		diffuse_radiance);

	const float3 surface_normal= tangent_frame[2];

	// calculate rim lighting
	float3 rim_color_diffuse;	
	{		
		float rim_ratio= saturate(dot(view_dir, bump_normal));
		rim_ratio= saturate( (rim_width - rim_ratio) / max(rim_width, 0.001f) );
		rim_ratio= pow(rim_ratio, rim_power);
		rim_color_diffuse= analytical_light_intensity * rim_ratio * rim_tint;	
	}	

	// calculate subsurface
	float3 subsurface_color;
	{
		float4 subsurface_map_color= tex2D(subsurface_map, texcoord);
		float3 subsurface_normal=
			lerp(lerp(surface_normal, bump_normal, subsurface_normal_detail), analytical_light_dir, subsurface_propagation_bias); 
		subsurface_normal= normalize(subsurface_normal);					

		float3 area_radiance_subsurface=
			saturate(dot(subsurface_normal, analytical_light_dir)) * analytical_light_intensity;

		subsurface_color= 
			area_radiance_subsurface *
			subsurface_tint *			
			subsurface_map_color.rgb;
	}

	// modify output 	
	diffuse_radiance+= rim_color_diffuse + subsurface_color;
}


float3 get_analytical_specular_multiplier_organism_ps(float specular_mask)
{	
	return calc_analytical_specular_multiplier(specular_mask);
}

float3 get_diffuse_multiplier_organism_ps()
{
	return calc_diffuse_multiplier();
}

void calc_material_analytic_specular_organism_ps(
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

	const float3 surface_normal= tangent_frame[2];

	// calculate rim lighting
	float3 rim_color_diffuse;	
	{		
		float rim_ratio= saturate(dot(view_dir, normal_dir));
		rim_ratio= saturate( (rim_width - rim_ratio) / max(rim_width, 0.001f) );
		rim_ratio= pow(rim_ratio, rim_power);
		rim_color_diffuse= light_irradiance * rim_ratio * rim_tint;	
	}	

	// calculate subsurface
	float3 subsurface_color;
	{
		float4 subsurface_map_color= tex2D(subsurface_map, texcoord);
		float3 subsurface_normal=
			lerp(lerp(surface_normal, normal_dir, subsurface_normal_detail), L, subsurface_propagation_bias); 
		subsurface_normal= normalize(subsurface_normal);					

		float3 area_radiance_subsurface=
			saturate(dot(subsurface_normal, L)) * light_irradiance;

		subsurface_color= 
			area_radiance_subsurface *
			subsurface_tint *			
			subsurface_map_color.rgb;
	}

	additional_diffuse_radiance= (rim_color_diffuse + subsurface_color) * diffuse_albedo_color;
}

#undef FORCE_BRANCH
#endif //_ORGANISM_MATERIAL_FX_