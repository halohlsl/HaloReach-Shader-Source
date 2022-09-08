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

#if defined(pc) && (DX_VERSION == 9)

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
PARAM_SAMPLER_2D_ARRAY(wave_displacement_array);
PARAM(float4, wave_displacement_array_xform);

PARAM_SAMPLER_2D_ARRAY(wave_slope_array);
PARAM(float4, wave_slope_array_xform);
PARAM(float, wave_height_aux);
PARAM(float, time_warp_aux);

PARAM(float, slope_scaler);

// no use samplers
PARAM_SAMPLER_2D(wave_mapping);
PARAM_SAMPLER_2D(subwave_1_mapping);
PARAM_SAMPLER_2D(subwave_2_mapping);

// waveshape parameters for ocean
PARAM(float, wave_height);
PARAM(float, time_warp);
PARAM(float, wave_orientation);
PARAM(float4, wave_mapping_xform);

PARAM(float, subwave_1_height);
PARAM(float, subwave_1_time_warp);
PARAM(float4, subwave_1_mapping_xform);

PARAM(float, subwave_2_height);
PARAM(float, subwave_2_time_warp);
PARAM(float4, subwave_2_mapping_xform);

PARAM_SAMPLER_2D(watercolor_texture);
PARAM(float4, watercolor_texture_xform);

PARAM_SAMPLER_2D(global_shape_texture);
PARAM(float4, global_shape_texture_xform);

PARAM_SAMPLER_CUBE(environment_map);

// foam texture
PARAM_SAMPLER_2D(foam_texture);
PARAM(float4, foam_texture_xform);
PARAM_SAMPLER_2D(foam_texture_detail);
PARAM(float4, foam_texture_detail_xform);
PARAM(float, foam_cut);
PARAM(float, foam_pow);
PARAM(float, foam_start_side);
PARAM(float, foam_coefficient);

// wave shape
PARAM(float, choppiness_forward);
PARAM(float, choppiness_backward);
PARAM(float, choppiness_side);
PARAM(float, wave_visual_damping_distance);
PARAM(float, subwave_visual_damping_distance);
PARAM(float, ocean_altitude);

PARAM(float, wave_tessellation_level);

PARAM(float, detail_slope_scale_x);
PARAM(float, detail_slope_scale_y);
PARAM(float, detail_slope_scale_z);
PARAM(float, detail_slope_steepness);

// refraction settings
PARAM(float, refraction_texcoord_shift);
PARAM(float, refraction_extinct_distance);
PARAM(float, minimal_wave_disturbance);

// water appearance
PARAM(float, reflection_coefficient);
PARAM(float, sunspot_cut);
PARAM(float, shadow_intensity_mark);
PARAM(float, normal_variation_tweak);

PARAM(float, fresnel_coefficient);
PARAM(float, fresnel_dark_spot);
PARAM(float3, water_color_pure);
PARAM(float, watercolor_coefficient);
PARAM(float3, water_diffuse);
PARAM(float, water_murkiness);

// bank alpha
PARAM(float, bankalpha_infuence_depth);

// global shape
PARAM(float, globalshape_infuence_depth);

//	ignore the vertex_type, input vertex type defined locally
struct s_vertex_type_water_tessellation
{
	uint index		:	SV_VertexID;
};

#ifdef pc

#define PC_WATER_TESSELLATION

struct s_vertex_type_water_shading
{
#ifdef PC_WATER_TESSELLATION
	//float4	pos1xyz_tc1x		: POSITION0;
	//float4	tc1y_tan1xyz		: POSITION1;
	//float4	bin1xyz_lm1x		: POSITION2;
	//float4	lm1y_pos2xyz		: POSITION3;
	//float4	tc2xy_tan2xy		: POSITION4;
   	//float4	tan2z_bin2xyz		: POSITION5;
   	//float4	lm2xy_pos3xy		: POSITION6;
   	//float4	pos3z_tc3xy_tan3x	: POSITION7;
   	//float4	tan3yz_bin3xy		: TEXCOORD0;
   	//float3	bin3z_lm3xy			: TEXCOORD1;

	float4	pos1xyz_tc1x		: POSITION0;
	float4	tc1y_tan1xyz		: POSITION1;
	float4	bin1xyz_lm1x		: POSITION2;
	float4	lm1y_mi1_pos2xy		: POSITION3;
	float4	posz_tc2xy_tan2x	: POSITION4;
	float4	tan2yz_bin2xy		: POSITION5;
	float4	bin2z_lm2xy_mi2		: POSITION6;
	float4	pos3xyz_tc3x		: POSITION7;
	float4	tc3y_tan3xyz		: TEXCOORD0;
	float4	bin3xyz_lm3x		: TEXCOORD1;
	float2	lm3y_mi3			: TEXCOORD2;

	float4	bt1xy_bt2xy			: NORMAL0;
	float2	bt3xy				: NORMAL1;

   	float3	bc					: TEXCOORD3;
#else
	float3   position		    : POSITION0;
	float2   texcoord		    : TEXCOORD0;
	float3   normal            	: NORMAL;
	float3   tangent           	: TANGENT;
	float3   binormal          	: BINORMAL;

	float2   lm_tex            	: TEXCOORD1;

	float3   base_texcoord     	: POSITION3;
#endif
};
#else
struct s_vertex_type_water_shading
{
	int index		:	SV_VertexID;

	// tessellation parameter
	float3 uvw		:	BARYCENTRIC;
	int quad_id		:	QUADID;
};
#endif // pc


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
	float4 position		:SV_Position;
	float4 texcoord		:TEXCOORD0;		// defaul texcoord.uv,
	float4 normal		:TEXCOORD1;		// tangent space
	float4 tangent		:TEXCOORD2;		// w = misc_info.x = height_scale
	float4 binormal		:TEXCOORD3;		// w = misc_info.y = height_scale_aux
	float4 position_ss	:TEXCOORD4;		//	position in screen space
	float4 incident_ws	:TEXCOORD5;		//	view incident direction in world space, incident_ws.w store the distannce between eye and current vertex
	float4 position_ws  :TEXCOORD6;		// w = misc_info.w = water_depth
	float4 base_tex		:TEXCOORD7;		// x, y (texcoord) z, w(vmf_intensity)		// texcoord_ripple.uv
	float4 lm_tex		:TEXCOORD8;		// lightmap color or uv coord
};

//	structure definition for underwater
struct s_underwater_vertex_input
{
	int index		:	SV_VertexID;
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
