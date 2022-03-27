/*
WATER.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

//This comment causes the shader compiler to be invoked for certain types
//@generate s_water_vertex



// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

#define SCOPE_LIGHTING

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
// We could automatically prepend this to the shader file when doing generate-templates, hmmm...
#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"

#define	BLEND_MODE_OFF	//	no blend for water

// Attempt to auto-synchronize constant and sampler registers between hlsl and cpp code.
#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#include "water\water_registers.fx"


#include "shared\render_target.fx"
//This comment causes the shader compiler to be invoked for certain types
//@generate s_water_vertex

// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))


// rename entry point of water passes 
#define water_dense_per_pixel_vs		static_per_pixel_vs
#define water_dense_per_pixel_ps		static_per_pixel_ps

#define water_flat_per_pixel_vs			single_pass_per_pixel_vs
#define water_flat_per_pixel_ps			single_pass_per_pixel_ps
#define water_flat_per_vertex_vs		single_pass_per_vertex_vs
#define water_flat_per_vertex_ps		single_pass_per_vertex_ps

#define water_flat_blend_per_pixel_vs	static_default_vs
#define water_flat_blend_per_pixel_ps	static_default_ps
#define water_flat_blend_per_vertex_vs	albedo_vs
#define water_flat_blend_per_vertex_ps	albedo_ps

#ifdef pc

struct s_water_interpolators
{
	float4 position	:POSITION0;
};

#ifdef VERTEX_SHADER
	#define DEFINE_NULL_SHADER(name)			\
		s_water_interpolators name##_vs()		\
		{										\
			s_water_interpolators OUT;			\
			OUT.position= 0.0f;					\
			return OUT;							\
		}
#endif //VERTEX_SHADER
#ifdef PIXEL_SHADER
	#define DEFINE_NULL_SHADER(name)										\
		float4 name##_ps(s_water_interpolators INTERPOLATORS) : COLOR0		\
		{																	\
			return float4(0,1,2,3);											\
		}
#endif // PIXEL_SHADER

DEFINE_NULL_SHADER(water_tessellation)
DEFINE_NULL_SHADER(water_dense_per_pixel)
DEFINE_NULL_SHADER(water_flat_per_pixel)
DEFINE_NULL_SHADER(water_flat_per_vertex)
DEFINE_NULL_SHADER(lightmap_debug_mode)
DEFINE_NULL_SHADER(water_flat_blend_per_pixel)
DEFINE_NULL_SHADER(water_flat_blend_per_vertex)

#else //xenon

/* Water profile contants and textures from tag*/
sampler3D wave_displacement_array;
float4 wave_displacement_array_xform;

sampler3D wave_slope_array;
float4 wave_slope_array_xform;
float wave_height_aux;
float time_warp_aux;

float slope_scaler;

// no use samplers
sampler wave_mapping;
sampler subwave_1_mapping;
sampler subwave_2_mapping;

// waveshape parameters for ocean
float wave_height;
float time_warp;
float wave_orientation;
float4 wave_mapping_xform;

float subwave_1_height;
float subwave_1_time_warp;
float4 subwave_1_mapping_xform;

float subwave_2_height;
float subwave_2_time_warp;
float4 subwave_2_mapping_xform;

sampler watercolor_texture;
float4 watercolor_texture_xform;

sampler global_shape_texture;
float4 global_shape_texture_xform;

samplerCUBE environment_map;

// foam texture
sampler foam_texture;
float4 foam_texture_xform;
sampler foam_texture_detail;
float4 foam_texture_detail_xform;
float foam_cut;
float foam_pow;
float foam_start_side;
float foam_coefficient;

// wave shape
float choppiness_forward;
float choppiness_backward;
float choppiness_side;
float wave_visual_damping_distance;
float subwave_visual_damping_distance;
float ocean_altitude;

float wave_tessellation_level;

float detail_slope_scale_x;
float detail_slope_scale_y;
float detail_slope_scale_z;
float detail_slope_steepness;

// refraction settings
float refraction_texcoord_shift;
float refraction_extinct_distance;
float minimal_wave_disturbance;

// water appearance
float reflection_coefficient;
float sunspot_cut;
float shadow_intensity_mark;
float normal_variation_tweak;

float fresnel_coefficient;
float fresnel_dark_spot;
float3 water_color_pure;
float watercolor_coefficient;
float3 water_diffuse;
float water_murkiness;

// bank alpha
float bankalpha_infuence_depth;

// global shape
float globalshape_infuence_depth;

//	ignore the vertex_type, input vertex type defined locally
struct s_vertex_type_water_tessellation
{
	int index		:	INDEX;
};

struct s_vertex_type_water_shading
{
	int index		:	INDEX;
 
	// tessellation parameter
	float3 uvw		:	BARYCENTRIC;
	int quad_id		:	QUADID;	
};


struct s_water_render_vertex
{
	float4 position;
	float4 texcoord;
	float4 normal;
	float4 tangent;
	float4 binormal;
	float4 base_tex;
	float4 lm_tex;
	float3 vmf_intensity;
};

// The following defines the protocol for passing interpolated data between the vertex shader 
// and the pixel shader.  
struct s_water_interpolators
{
	float4 position		:POSITION0;
	float4 texcoord		:TEXCOORD0;		// defaul texcoord.uv, 
	float4 normal		:TEXCOORD1;		// tangent space
	float4 tangent		:TEXCOORD2;
	float4 binormal		:TEXCOORD3;	
	float4 position_ss	:TEXCOORD4;		//	position in screen space
	float4 incident_ws	:TEXCOORD5;		//	view incident direction in world space, incident_ws.w store the distannce between eye and current vertex
	float4 position_ws  :TEXCOORD6;		
	float4 base_tex		:TEXCOORD7;		// x, y (texcoord) z, w(vmf_intensity)		// texcoord_ripple.uv
	float4 lm_tex		:TEXCOORD8;		// lightmap color or uv coord
};

//	structure definition for underwater
struct s_underwater_vertex_input
{
	int index		:	INDEX;
};

/* implementation */
#include "water\water_tessellation.fx"
#include "water\water_shading.fx"

#endif //pc

#undef water_dense_per_pixel_vs
#undef water_dense_per_pixel_ps

#undef water_flat_per_pixel_vs
#undef water_flat_per_pixel_ps
#undef water_flat_per_vertex_vs
#undef water_flat_per_vertex_ps

#undef water_flat_blend_per_pixel_vs
#undef water_flat_blend_per_pixel_ps
#undef water_flat_blend_per_vertex_vs
#undef water_flat_blend_per_vertex_ps
