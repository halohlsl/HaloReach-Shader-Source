#ifndef _COOK_TORRANCE_CORE_FX_
#define _COOK_TORRANCE_CORE_FX_

/* ----------------------------------------------------------
cook_torrance_core.fx
6-17-2009 xwan.
the core implementation of cook torrance material mode, which 
will be shared between cook-torrance and skin(organism) shaders.
---------------------------------------------------------- */


#include "templated\materials\diffuse_specular.fx"
#include "templated\materials\power_roughness_conversion.fx"


/* -------------- parameter list --------------------------
all dedicated external parameters for cook-torrance
the organism materials has a super-set of parameter list
of cook-torrance.
---------------------------------------------------------- */

float	roughness;					//roughness
float	albedo_blend;				//how much to blend in the albedo color to fresnel f0
float	analytical_roughness;		//point light roughness

#if ALBEDO_TYPE(calc_albedo_ps) != ALBEDO_TYPE_calc_albedo_four_change_color_applying_to_specular_ps

float3	fresnel_color;				//reflectance at normal incidence
float3	specular_tint;

#else

#define fresnel_color tertiary_change_color
#define specular_tint quaternary_change_color

#endif


float fresnel_curve_steepness;

// alias
#define normal_specular		specular_tint
#define glancing_specular	fresnel_color

// marco
#define SQR(x) ((x)*(x))


/* -------------- function list -------------------------- */

float calc_specular_power_scale(float power_or_roughness)
{
}

float3 calc_analytical_specular_multiplier(float specular_mask)
{
	return specular_mask * specular_coefficient * analytical_specular_contribution; 
}

float3 calc_diffuse_multiplier()
{
	return diffuse_coefficient;
}

static void calculate_fresnel(
	in float3 view_dir,				
	in float3 normal_dir,
	in float3 albedo_color,
	out float power,
	out float3 normal_specular_blend_albedo_color,
	out float3 final_specular_color)
{
    float n_dot_v = saturate(dot( normal_dir, view_dir ));
    float fresnel_blend= pow(1.0f - n_dot_v, fresnel_curve_steepness);
    power= analytical_roughness;

    normal_specular_blend_albedo_color= lerp(normal_specular, albedo_color, albedo_blend);
    final_specular_color= lerp(normal_specular_blend_albedo_color, glancing_specular, fresnel_blend);   
}

// for point light source only
float3 calc_material_analytic_specular(
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
	out float3 analytic_specular_radiance)
{
    float3 final_specular_color;
	float specular_power;
	calculate_fresnel(
	    view_dir, 
	    normal_dir, 
	    diffuse_albedo_color, 
	    specular_power, 
	    normal_specular_blend_albedo_color,
	    final_specular_color);

    // the following parameters can be supplied in the material texture
    // r: specular coefficient
    // g: albedo blend
    // b: environment contribution
    // a: roughless
    spatially_varying_material_parameters = float4(specular_coefficient, albedo_blend, environment_map_specular_contribution, specular_power);
    if (use_material_texture)
    {	
	    //over ride shader supplied values with what's from the texture
	    float	power_modifier=	tex2D(material_texture, transform_texcoord(texcoord, material_texture_xform)).a;
	    spatially_varying_material_parameters.w=	lerp(material_texture_black_roughness, spatially_varying_material_parameters.w, power_modifier);
		spatially_varying_material_parameters.r	*=	lerp(material_texture_black_specular_multiplier, 1.0f, power_modifier);
    }
    
    float3 f0=normal_specular_blend_albedo_color;
    float3 f1=glancing_specular;

    float fVDotN=(dot(view_dir,normal_dir));
    float fLDotN=(dot(L,normal_dir));

    float3 H=normalize(L+view_dir);
    float fNDotH=(dot(H,normal_dir));
    float fHDotV=(dot(view_dir,H));
    
	float D= 0;
    float G;
    float D_area;
    float3 F;    
	
	//Beckmann distribution
    {	    
	    float m;//Root mean square slope of microfacets 
	    float sqr_tan_alpha= (1 - fNDotH * fNDotH) / (fNDotH * fNDotH);
	    m=saturate(spatially_varying_material_parameters.a);
	    D= exp( -sqr_tan_alpha / SQR(m) )/( SQR(m) * SQR( SQR(fNDotH)) + 0.00001f);
    }

	// fresnel
	{
	#if 0
		float blend_weight= pow((1-fHDotV),fresnel_curve_steepness);
		F=f0+(f1-f0)*blend_weight;
	#else
		F= final_specular_color;
	#endif
	}

	// calc G
	{
		float G1=2*fNDotH*fVDotN/fHDotV;
		float G2=2*fNDotH*fLDotN/fHDotV;
		G=saturate(min(G1,G2));
	}

	analytic_specular_radiance= D * G * F /(fVDotN)/3.141592658*light_irradiance;	
	return final_specular_color;	
}		


void calc_material_full(
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

#ifdef pc
	if (p_shader_pc_specular_enabled!=0.f)
#endif // pc
	{		
		float3 normal_specular_blend_albedo_color;		// specular_albedo (no fresnel)
		float4 per_pixel_parameters;
		float3 specular_analytical;			// specular radiance
		float4 spatially_varying_material_parameters;
		
		float3 final_specular_tint_color= calc_material_analytic_specular(
			view_dir,
			view_normal,
			view_reflect_dir_world,
			view_light_dir,
			light_color,
			albedo_color,
			texcoord,
			prt_ravi_diff.w,
			tangent_frame,
			spatially_varying_material_parameters,			
			normal_specular_blend_albedo_color,
			specular_analytical);

		//specular_analytical*=sh_lighting_coefficients[0].a;
		
		float3 simple_light_diffuse_light; //= 0.0f;
		float3 simple_light_specular_light; //= 0.0f;

		[branch]
		if (!no_dynamic_lights)
		{
			float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
			calc_simple_lights_analytical(
				fragment_position_world,
				view_normal,
				view_reflect_dir_world,											// view direction = fragment to camera,   reflected around fragment normal
				roughness_to_power(spatially_varying_material_parameters.a),
				simple_light_diffuse_light,
				simple_light_specular_light);
			simple_light_specular_light*= final_specular_tint_color;
		}
		else
		{
			simple_light_diffuse_light= 0.0f;
			simple_light_specular_light= 0.0f;
		}

		float3 sh_glossy= 0.0f;
		// calculate area specular
		//float r_dot_l= max(dot(view_light_dir, view_reflect_dir_world), 0.0f) * 0.65f + 0.35f;
		float r_dot_l= saturate(dot(view_light_dir, view_reflect_dir_world));

		//calculate the area sh
		float3 specular_part=0.0f;
		float3 schlick_part=0.0f;
		
		{
			float4 vmf[4];
			vmf[0]=sh_lighting_coefficients[0];
			vmf[1]=sh_lighting_coefficients[1];
			vmf[2]=sh_lighting_coefficients[2];
			vmf[3]=sh_lighting_coefficients[3];
	

			dual_vmf_diffuse_specular_with_fresnel(
				view_dir,
				view_normal,
				vmf,
				final_specular_tint_color,
				roughness,
				sh_glossy);
		}
						
		envmap_specular_reflectance_and_roughness.w= spatially_varying_material_parameters.a;
		envmap_area_specular_only= envmap_area_specular_only * final_specular_tint_color.rgb + sh_glossy * prt_ravi_diff.z;
				
		//scaling and masking
		specular_radiance.xyz= specular_mask * spatially_varying_material_parameters.r * 
			(
			(simple_light_specular_light + specular_analytical) * 
			analytical_specular_contribution +
			max(sh_glossy, 0.0f) * area_specular_contribution);
			
		specular_radiance.w= 0.0f;
			
		envmap_specular_reflectance_and_roughness.xyz =	spatially_varying_material_parameters.b * 
			specular_mask * 
			spatially_varying_material_parameters.r;		// ###ctchou $TODO this ain't right
				
		diffuse_radiance= diffuse_radiance * prt_ravi_diff.x;
		diffuse_radiance= (simple_light_diffuse_light + diffuse_radiance) * diffuse_coefficient;
		specular_radiance*= prt_ravi_diff.z;		
		
		//diffuse_color= 0.0f;
		//specular_color= spatially_varying_material_parameters.r;
	}
#ifdef pc
	else
	{
		envmap_specular_reflectance_and_roughness= float4(0.f, 0.f, 0.f, 0.f);
		envmap_area_specular_only= float3(0.f, 0.f, 0.f);
		specular_radiance= 0.0f;
		diffuse_radiance= 0;
	}
#endif // pc
	return;
}

#endif //_COOK_TORRANCE_CORE_FX_