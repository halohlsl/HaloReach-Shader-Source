#include "shared\utilities.fx"
#include "shared\spherical_harmonics.fx"
#include "lights\simple_lights.fx"


#ifndef PRE_MATERIAL_SHADER
#define PRE_MATERIAL_SHADER(texcoord)
#endif // PRE_MATERIAL_SHADER


// enumerate all material models
#define MATERIAL_TYPE(material) MATERIAL_TYPE_##material
#define MATERIAL_TYPE_diffuse_only 0
#define MATERIAL_TYPE_cook_torrance 1
#define MATERIAL_TYPE_two_lobe_phong 2
#define MATERIAL_TYPE_foliage 3
#define MATERIAL_TYPE_none 4
#define MATERIAL_TYPE_glass 5
#define MATERIAL_TYPE_organism 6
#define MATERIAL_TYPE_single_lobe_phong 7
#define MATERIAL_TYPE_hair 8
#define MATERIAL_TYPE_custom_specular 9

// all material models must define these 4 functions
#define CALC_MATERIAL(material) calc_material_##material##_ps
#define CALC_MATERIAL_SPECULAR_PARAMETERS(material) calc_material_specular_parameters_##material##_ps
#define CALC_MATERIAL_ANALYTIC_SPECULAR(material) calc_material_analytic_specular_##material##_ps

#define GET_MATERIAL_SPECULAR_POWER(material) get_material_##material##_specular_power
#define GET_MATERIAL_ANALYTICAL_SPECULAR_MULTIPLIER(material) get_analytical_specular_multiplier_##material##_ps
#define GET_MATERIAL_DIFFUSE_MULTIPLIER(material) get_diffuse_multiplier_##material##_ps

/*

Material model parameters:

// local directions
	in float3 view_dir,							// direction towards camera
	in float3 surface_normal,					// surface normal, calculated by calc_bump_ps	
	in float3 view_reflect_dir,					// view_dir reflected about surface_normal

// incident lighting
	in float4 sh_lighting_coefficients[4],		// describes incident area light in spherical harmonics
	in float3 analytical_light_dir,				// analytical light direction
	in float3 analytical_light_intensity,		// analytical light intensity

// material properties	
	in float3 diffuse_reflectance,				// diffuse reflectance, calculated by calc_diffuse_ps
	in float  specular_mask,					// specular mask (multiplies specular albedo)
	in float2 texcoord,							// texture coordinates (if needed for looking up material property textures)

// output environment map parameters
	out float4 envmap_specular_reflectance_and_roughness,		// apparent specular reflectance, including metallic/plastic effects, fresnel, specular mask, etc.   roughness in w channel
	out float3 envmap_area_specular_only,						// pristine area specular result (not scaled or added with analytical) - for use by envmap
	
// output light
	out float3 specular_radiance,				// the specularly reflected light as calculated by the material model
	inout float3 diffuse_radiance)				// the diffusely reflected light as calculated by the material model

*/

//parameters common to all material models
PARAM(float,	diffuse_coefficient);						//how much to scale diffuse by
PARAM(float,	specular_coefficient);						//how much to scale specular by
PARAM(float,	area_specular_contribution);					//scale the area sh contribution
PARAM(float,	analytical_specular_contribution);					//scale the analytical sh contribution
PARAM(float,	environment_map_specular_contribution);			//scale the environment map contribution
PARAM_SAMPLER_2D(material_texture);					//a texture that stores spatially varient parameters
PARAM(float4,	material_texture_xform);				//texture matrix
PARAM(bool, use_material_texture);
PARAM(float, material_texture_black_roughness);
PARAM(float, material_texture_black_specular_multiplier);

#define order3_area_specular false


//*****************************************************************************
// diffuse only
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_diffuse_only
#include "templated\materials\diffuse_only.fx"
#endif

//*****************************************************************************
// cook torrance
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_cook_torrance
#include "templated\materials\cook_torrance.fx"
#define NO_ALPHA_TO_COVERAGE
#endif

//*****************************************************************************
// two lobe phong model
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_two_lobe_phong
#include "templated\materials\two_lobe_phong.fx"
#define NO_ALPHA_TO_COVERAGE
#endif

//*****************************************************************************
// foliage
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_foliage
#include "templated\materials\foliage_material.fx"
#endif

//*****************************************************************************
// organism
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_organism
#include "templated\materials\organism_material.fx"
#define NO_ALPHA_TO_COVERAGE
#endif


//*****************************************************************************
// none
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_none
#include "templated\materials\material_model_none.fx"
#endif

//*****************************************************************************
// single lobe phong model
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_single_lobe_phong
#include "templated\materials\single_lobe_phong.fx"
#define NO_ALPHA_TO_COVERAGE
#endif

//*****************************************************************************
// hair
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_hair
#include "templated\materials\hair_material.fx"
#define NO_ALPHA_TO_COVERAGE
#endif

//*****************************************************************************
// custom specular
//*****************************************************************************
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_custom_specular
#include "templated\materials\custom_specular.fx"
#define NO_ALPHA_TO_COVERAGE
#endif
