#define BLEND_MODE_OFF   // no blending in this shader
#include "templated\templated_globals.fx"

#include "templated\analytical_mask.fx"

#if (!defined(pc)) || (DX_VERSION == 11)
#define ALPHA_OPTIMIZATION
#endif

#define GAMMA2 true

#define NO_ALPHA_TO_COVERAGE

#include "shared\utilities.fx"
#include "shared\albedo_pass.fx"
#include "shared\render_target.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"
#include "templated\environment_mapping.fx"
#include "shared\spherical_harmonics.fx"
#include "lights\simple_lights.fx"
#include "templated\debug_modes.fx"
#include "templated\velocity.fx"
#include "templated\entry.fx"
#include "shadows\shadow_mask.fx"

#include "templated\lightmap_sampling.fx"
#include "templated\pc_lighting.fx"
#include "templated\wetness.fx"
#include "lights\uber_light.fx"
#include "shared\clip_plane.fx"
#include "shared\dynamic_light_clip.fx"

void calc_alpha_test_ps(in float2 texcoord)
{
}
#include "shared\atmosphere.fx"
#include "shadows\shadow_generate.fx"

#if defined(entry_point_imposter_static_sh)
	#define static_sh_vs imposter_static_sh_vs
	#define static_sh_ps imposter_static_sh_ps
	#define SHADER_FOR_IMPOSTER
#elif defined(entry_point_imposter_static_prt_ambient)
	#define static_prt_ambient_vs imposter_static_prt_ambient_vs
	#define static_prt_ps imposter_static_prt_ps
	#define SHADER_FOR_IMPOSTER
#endif


//=============================================================================
//categories
//  - blending
//  - environment_map
//  - material_0
//  - material_1
//  - material_2
//  - material_3
//=============================================================================


//================
// parameters
//================


PARAM_SAMPLER_2D(blend_map);
PARAM(float4, blend_map_xform);

PARAM(float, global_albedo_tint);

#define ACTIVE_MATERIAL(material_type) ACTIVE_##material_type
#define ACTIVE_diffuse_only 1
#define ACTIVE_diffuse_plus_specular 1
#define ACTIVE_off 0
#define ACTIVE_MATERIAL_COUNT (ACTIVE_MATERIAL(material_0_type) + ACTIVE_MATERIAL(material_1_type) + ACTIVE_MATERIAL(material_2_type) + ACTIVE_MATERIAL(material_3_type))

#define SPECULAR_MATERIAL(material_type) SPECULAR_##material_type
#define SPECULAR_diffuse_only 0
#define SPECULAR_diffuse_plus_specular 1
#define SPECULAR_off 0
#define SPECULAR_MATERIAL_COUNT (SPECULAR_MATERIAL(material_0_type) + SPECULAR_MATERIAL(material_1_type) + SPECULAR_MATERIAL(material_2_type) + SPECULAR_MATERIAL(material_3_type))

#define DETAIL_BUMP_ENABLED (ACTIVE_MATERIAL_COUNT < 4)

#define MORPH_morph 0
#define MORPH_dynamic 1
#define MORPH_distance_blend_base 2
#define MORPH_DYNAMIC(blend_option) (MORPH_##blend_option == MORPH_dynamic)
#define DISTANCE_BLEND_BASE(blend_option) (MORPH_##blend_option == MORPH_distance_blend_base)

#define raised_area_specular_scalar 0.6f
#define raised_area_specular_offset 0.005f

#if MORPH_DYNAMIC(blend_type)
    PARAM(float4, dynamic_material);
    PARAM(float, transition_sharpness);
    PARAM(float, transition_threshold);
#endif // MORPH_DYNAMIC


#if DISTANCE_BLEND_BASE(blend_type)

	PARAM(float4, blend_target_0);
	PARAM(float4, blend_target_1);
	PARAM(float4, blend_target_2);
	PARAM(float4, blend_target_3);

	PARAM(float, blend_slope);
	PARAM(float, blend_offset);

	PARAM(float, blend_max_0);
	PARAM(float, blend_max_1);
	PARAM(float, blend_max_2);
	PARAM(float, blend_max_3);

	#define BLEND_BASE(base, base_blend, material) distance_blend_base_to_target(base, base_blend, blend_max_##material, blend_target_##material)
	#define SETUP_BASE_BLEND(dist)	saturate(dist * blend_slope + blend_offset)

	void distance_blend_base_to_target(inout float4 base, in float base_blend, in float blend_max, in float4 blend_target)
	{
		float amount=	min(base_blend, blend_max);
		base= lerp(base, blend_target, amount);
		return;
	}

#else // !DISTANCE_BLEND_BASE
	#define BLEND_BASE(base, base_blend, material)
	#define SETUP_BASE_BLEND(dist) 0
#endif // DISTANCE_BLEND_BASE


#define DECLARE_MATERIAL(material_number)                               \
PARAM_SAMPLER_2D(base_map_m_##material_number);                         \
PARAM(float4, base_map_m_##material_number##_xform);                    \
PARAM_SAMPLER_2D(detail_map_m_##material_number);                       \
PARAM(float4, detail_map_m_##material_number##_xform);                  \
PARAM_SAMPLER_2D(bump_map_m_##material_number);                         \
PARAM(float4, bump_map_m_##material_number##_xform);                    \
PARAM_SAMPLER_2D(detail_bump_m_##material_number);                      \
PARAM(float4, detail_bump_m_##material_number##_xform);                 \
PARAM(float, diffuse_coefficient_m_##material_number);                  \
PARAM(float, specular_coefficient_m_##material_number);                 \
PARAM(float, specular_power_m_##material_number);                       \
PARAM(float3, specular_tint_m_##material_number);                       \
PARAM(float, fresnel_curve_steepness_m_##material_number);              \
PARAM(float, area_specular_contribution_m_##material_number);           \
PARAM(float, analytical_specular_contribution_m_##material_number);     \
PARAM(float, environment_specular_contribution_m_##material_number);    \
PARAM(float, albedo_specular_tint_blend_m_##material_number);


DECLARE_MATERIAL(0);
DECLARE_MATERIAL(1);
DECLARE_MATERIAL(2);
DECLARE_MATERIAL(3);


float4 sample_blend_normalized(float2 texcoord)
{

    float4 blend= sample2D(blend_map, transform_texcoord(texcoord, blend_map_xform));
#if DX_VERSION == 11
    blend += 0.00000001f;       // this gets rid of pure black pixels in the blend map.  We've decided that this isn't worth the instruction - just change your blend map
                                // but in the D3D11 build there are a few maps that cause us trouble and we don't want to change the blend maps :)
#endif

    #if MORPH_DYNAMIC(blend_type)
       // alpha blend dynamic material
       float alpha= (blend.w - transition_threshold) * transition_sharpness;
       blend.w= 0.0f;
       blend= lerp(blend, dynamic_material, saturate(alpha));
    #endif // MORPH_DYNAMIC

    float blend_sum= 0;
    #if ACTIVE_MATERIAL(material_0_type)
       blend_sum += blend.x;
    #endif
    #if ACTIVE_MATERIAL(material_1_type)
       blend_sum += blend.y;
    #endif
    #if ACTIVE_MATERIAL(material_2_type)
       blend_sum += blend.z;
    #endif
    #if ACTIVE_MATERIAL(material_3_type)
       blend_sum += blend.w;
    #endif

    blend.xyzw= (blend.xyzw) / blend_sum;       // normalize blend so that the sum of active channels is 1.0

    return blend;
}


float4 sample_blend_normalized_for_lighting(float2 texcoord)
{
#if SPECULAR_MATERIAL_COUNT > 0
    return sample_blend_normalized(texcoord);
#else
    return 1.0f / ACTIVE_MATERIAL_COUNT;
#endif
}


void calc_bumpmap(
    in float2 texcoord,
    in texture_sampler_2d bump_map,
    in float4 bump_map_xform,
    in texture_sampler_2d detail_bump,
    in float4 detail_bump_xform,
    out float2 bump)
{
    bump.xy= sample2D(bump_map, transform_texcoord(texcoord, bump_map_xform));

#if DETAIL_BUMP_ENABLED
    float2 detail= sample2D(detail_bump, transform_texcoord(texcoord, detail_bump_xform));
    bump.xy += detail.xy;
#endif
}

void calc_phong_outgoing_light(
    // geometric parameters in world space
    in float3    normal_dir,
    in float3    reflection_dir,
    in float     n_dot_v,
    // phong lobe parameters
    in float     specular_power,
    // incident light parameters
    in float3    analytical_light_dir,
    in float3    analytical_light_color,
    // outgoing light (towards view)
    out float3   analytical_specular_light)
{
    // calculate analyical specular light
    float n_dot_l = dot(normal_dir, analytical_light_dir);
	float l_dot_r = max(dot(analytical_light_dir, reflection_dir), 0.0f);
    if (n_dot_l > 0 && n_dot_v > 0 )
    {
		analytical_specular_light= analytical_light_color * (pow(l_dot_r, specular_power) * ((specular_power + 1.0f) / 6.2832));
    }
    else
    {
       analytical_specular_light= 0.0f;
    }
}

//=============================================================================
//entry points
//  - albedo
//  - static_per_pixel
//  - static_per_vertex
//  - static_sh
//  - shadow_apply
//  - dynamic_light
//=============================================================================


void default_vertex_transform_vs(
    inout vertex_type vertex,
    out float4 position,
    out float2 texcoord,
    out float3 normal,
    out float3 binormal,
    out float3 tangent,
    out float3 fragment_to_camera_world,
    out float4 local_to_world_transform[3])
{
    //output to pixel shader
    always_local_to_view(vertex, local_to_world_transform, position, binormal);

    texcoord= vertex.texcoord;
    normal= vertex.normal;
    tangent= vertex.tangent;
    //binormal= vertex.binormal;

    // world space vector from vertex to eye/camera
    fragment_to_camera_world= Camera_Position - vertex.position;
}

void default_vertex_transform_vs_fast(
    inout vertex_type vertex,
    out float4 position,
    out float2 texcoord,
    out float3 normal,
    out float3 fragment_to_camera_world,
    out float4 local_to_world_transform[3])
{
    //output to pixel shader
    always_local_to_view_fast(vertex, local_to_world_transform, position);

    texcoord= vertex.texcoord;
    normal=   vertex.normal;

    // world space vector from vertex to eye/camera
    fragment_to_camera_world= Camera_Position - vertex.position;
}

//================
// albedo
//================

void albedo_vs(
    in vertex_type vertex,
    out float4 position : SV_Position,
    CLIP_OUTPUT
    out float4 texcoord : TEXCOORD0,
    out float3 normal : TEXCOORD1,
    out float3 binormal : TEXCOORD2,
    out float3 tangent : TEXCOORD3)
{
    float3 fragment_to_camera_world;
    float4 local_to_world_transform_UNUSED[3];
    default_vertex_transform_vs(vertex, position, texcoord.xy, normal, binormal, tangent, fragment_to_camera_world, local_to_world_transform_UNUSED);
    texcoord.z= 0.0f;
   	texcoord.w=	length(fragment_to_camera_world);

	CALC_CLIP(position);
}

#define DETAIL_MULTIPLIER 4.59479f

#ifndef pc
#define COMPILER_IFANY [ifAny]
#define COMPILER_PREDBLOCK [predicateBlock]     /* forcing this is actually slower */
#define COMPILER_PREDICATE [predicate]       /* forcing this is even slower  */
#define COMPILER_BRANCH [branch]          /* forcing this is slower too  */
//[reduceTempRegUsage(5)]               /* this doesn't appear to help at all  */
#else
#define COMPILER_IFANY
#define COMPILER_PREDBLOCK
#define COMPILER_PREDICATE
#define COMPILER_BRANCH
#endif

#define ACCUMULATE_MATERIAL_ALBEDO_AND_BUMP(material, blend_amount, albedo_accumulate, blendweight, bump)               \
if (blend_amount > 0.04)                                                                     \
{                                                                                \
    float4 base=      sample2D(base_map_m_##material,  transform_texcoord(original_texcoord, base_map_m_##material##_xform));     \
	BLEND_BASE(base, base_blend, material);																						\
    float4 detail=    sample2D(detail_map_m_##material, transform_texcoord(original_texcoord, detail_map_m_##material##_xform));    \
    albedo_accumulate += base * detail * blendweight;                                              \
  {                                                                               \
       float2 material_bump_normal;                                                          \
       calc_bumpmap(                                                                    \
         original_texcoord,                                                               \
         bump_map_m_##material,                                                            \
         bump_map_m_##material##_xform,                                                         \
         detail_bump_m_##material,                                                           \
         detail_bump_m_##material##_xform,                                                     \
         material_bump_normal);                                                            \
       bump_normal.xy += material_bump_normal * blend_amount;                                               \
    }                                                                             \
}

albedo_pixel albedo_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    CLIP_INPUT
    in float4 original_texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3)
{
	float dist=			original_texcoord.w;							//	length(fragment_to_camera_world);
	float base_blend=	SETUP_BASE_BLEND(dist);

    float4 blend= sample_blend_normalized(original_texcoord);
    float4 albedo= 0.0f;
    float3 bump_normal= 0.0f;

    #if ACTIVE_MATERIAL(material_0_type)
       ACCUMULATE_MATERIAL_ALBEDO_AND_BUMP(0, blend.x, albedo, blend.xxxx, bump_normal);
    #endif

    #if ACTIVE_MATERIAL(material_1_type)
       ACCUMULATE_MATERIAL_ALBEDO_AND_BUMP(1, blend.y, albedo, blend.yyyy, bump_normal);
    #endif

    #if ACTIVE_MATERIAL(material_2_type)
       ACCUMULATE_MATERIAL_ALBEDO_AND_BUMP(2, blend.z, albedo, blend.zzzz, bump_normal);
    #endif

    #if ACTIVE_MATERIAL(material_3_type)
       ACCUMULATE_MATERIAL_ALBEDO_AND_BUMP(3, blend.w, albedo, blend.wwww, bump_normal);
    #endif
    albedo.xyz *= global_albedo_tint * DETAIL_MULTIPLIER;

//  bump_normal.z= saturate(bump_normal.x*bump_normal.x + bump_normal.y*bump_normal.y);   // recalculating Z here saves a few GPRs and ALUs ...  but not as contrasty bump.  We're always texture bound anyways, so leave this out
//  bump_normal.z= sqrt(1 - bump_normal.z);
//  bump_normal= normalize(bump_normal);

#if !defined(pc) || (DX_VERSION == 11)
    bump_normal.z= saturate(bump_normal.x*bump_normal.x + bump_normal.y*bump_normal.y);
    bump_normal.z= sqrt(1 - bump_normal.z);
//  bump_normal= normalize(bump_normal);
#endif

#ifndef ALPHA_OPTIMIZATION
    normal= normalize(normal);
    binormal= normalize(binormal);
    tangent= normalize(tangent);
#endif

    // setup tangent frame
    float3x3 tangent_frame = {tangent, binormal, normal};

    // rotate bump normal into world space
    bump_normal= mul(bump_normal, tangent_frame);

#if defined(pc) && (DX_VERSION == 9)
    apply_pc_albedo_modifier(albedo, bump_normal);
#endif

    float approximate_specular_type= 0.667f;
    return convert_to_albedo_target(albedo, bump_normal, approximate_specular_type);
}

#if ENTRY_POINT(entry_point) == ENTRY_POINT_static_per_pixel

#define must_be_environment

struct entry_point_data
{
    float2 lightmap_texcoord;
};
#define BUILD_ENTRY_POINT_DATA(data)    { data.lightmap_texcoord= texcoord_and_lightmap_uv.zw; }

void get_sh_coefficients(
    inout entry_point_data data,
    out float4 vmf_lighting_coefficients[4])
{

    sample_lightprobe_texture(
       data.lightmap_texcoord,
       vmf_lighting_coefficients);
}

#elif ((ENTRY_POINT(entry_point) == ENTRY_POINT_static_sh) || (ENTRY_POINT(entry_point) == ENTRY_POINT_imposter_static_sh) || (ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_quadratic) || (ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_linear) || (ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_ambient) || (ENTRY_POINT(entry_point) == ENTRY_POINT_imposter_static_prt_ambient) )

struct entry_point_data
{
    float4 unused;
};
#define BUILD_ENTRY_POINT_DATA(data)    { data.unused= 0.0f; }

void get_sh_coefficients(
    inout entry_point_data data,
    out float4 sh_lighting_coefficients[4])
{
    sh_lighting_coefficients[0]= p_vmf_lighting_constant_0;
    sh_lighting_coefficients[1]= p_vmf_lighting_constant_1;
    sh_lighting_coefficients[2]= p_vmf_lighting_constant_2;
    sh_lighting_coefficients[3]= p_vmf_lighting_constant_3;
}

#elif ENTRY_POINT(entry_point) == ENTRY_POINT_static_per_vertex

#define must_be_environment

struct entry_point_data
{
    float4 vmf0;
    float4 vmf1;
    float4 vmf2;
    float4 vmf3;
};

#define BUILD_ENTRY_POINT_DATA(data){ data.vmf0= vmf0;  data.vmf1= vmf1; data.vmf2= vmf2; data.vmf3= vmf3;}
void get_sh_coefficients(
    inout entry_point_data data,
    out float4 sh_lighting_coefficients[4])
{
    sh_lighting_coefficients[0]= data.vmf0;
    sh_lighting_coefficients[1]= data.vmf1;
    sh_lighting_coefficients[2]= data.vmf2;
    sh_lighting_coefficients[3]= data.vmf3;
}


#else

struct entry_point_data
{
};
#define BUILD_ENTRY_POINT_DATA(data)    ERROR_you_must_define_entry_point

void get_sh_coefficients(
    inout entry_point_data data,
    out float4 sh_lighting_coefficients[4])
{
    sh_lighting_coefficients[0]= float4(1.0f, 0.0f, 1.0f, 0.0f);
    sh_lighting_coefficients[1]= float4(0.0f, 0.0f, 0.0f, 0.0f);
    sh_lighting_coefficients[2]= float4(0.0f, 0.0f, 0.0f, 0.0f);
    sh_lighting_coefficients[3]= float4(0.0f, 0.0f, 0.0f, 0.0f);
}

#endif



//===================
// static_per_pixel
//===================

void static_per_pixel_vs(
    in vertex_type vertex,
    in s_lightmap_per_pixel lightmap,
    #if !defined(pc) || (DX_VERSION == 11)
       in uint vertex_index : SV_VertexID,       // use vertex_index to fetch wetness info
    #endif // !pc
    out float4 position						: SV_Position,
    CLIP_OUTPUT
    out float4 texcoord_and_lightmap_uvs	: TEXCOORD0,	// xy: original texcoord, zw: lightmap uvs
    out float4 normal_and_extinction		: TEXCOORD1,	// xyz: vertex normal, w: extinction parameter
    out float3 fragment_to_camera_world		: TEXCOORD2,
    out float4 inscatter_wetness			: TEXCOORD3)
{
    float4 local_to_world_transform_UNUSED[3];
    default_vertex_transform_vs_fast(vertex, position, texcoord_and_lightmap_uvs.xy, normal_and_extinction.xyz, fragment_to_camera_world, local_to_world_transform_UNUSED);

    texcoord_and_lightmap_uvs.zw= lightmap.texcoord;

    compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, normal_and_extinction.w);

    // calc wetness
    inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
}

struct specular_parameters
{
    float4 normal_albedo;			// specular albedo along normal (plus albedo blend in alpha)
    float power;					// specular power
    float analytical;				// analytical contribution  (* specular contribution)
    float area;						// area contribution       (* specular contribution)
    #if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none
		float envmap;				// envmap contribution   (* specular contribution)
	#endif

    float fresnel_steepness;		// averaged across specular only
    float weight;
};

#if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none

// Environment map is enabled for this shader

#define BLEND_SPECULAR_WITH_ENVIRONMENT_MAP_CONTRIBUTION(material_postfix, blend_amount, specular)		\
    blend_specular_parameters_with_environment_contribution(			\
		blend_amount,													\
		specular_tint_##material_postfix,								\
		albedo_specular_tint_blend_##material_postfix,                  \
		specular_power_##material_postfix,                              \
		specular_coefficient_##material_postfix,						\
		analytical_specular_contribution_##material_postfix,            \
		area_specular_contribution_##material_postfix,                  \
		environment_specular_contribution_##material_postfix,			\
		fresnel_curve_steepness_##material_postfix,                     \
		specular)

void blend_specular_parameters_with_environment_contribution(
    in float blend_amount,
    in float3 specular_tint,
    in float albedo_specular_tint_blend,
    in float specular_power,
    in float specular_coefficient,
    in float analytical_specular_contribution,
    in float area_specular_contribution,
	in float environment_specular_contribution,
    in float fresnel_steepness,
    inout specular_parameters specular)
{
    specular.normal_albedo.rgb   += blend_amount * specular_tint * (1.0 - albedo_specular_tint_blend);
    specular.normal_albedo.w     += blend_amount * albedo_specular_tint_blend;

    specular.power               += blend_amount * specular_power;
    specular.analytical          += blend_amount * specular_coefficient * analytical_specular_contribution;         // ###ctchou $PERF can move specular_coefficient outside this blend
    specular.area                += blend_amount * specular_coefficient * area_specular_contribution;
	specular.envmap				 += blend_amount * specular_coefficient * environment_specular_contribution;

    specular.fresnel_steepness   += blend_amount * fresnel_steepness;
    specular.weight              += blend_amount;
}

#define BLEND_SPECULAR BLEND_SPECULAR_WITH_ENVIRONMENT_MAP_CONTRIBUTION

#else

// Environment map is disabled for this shader (compiled out)

#define BLEND_SPECULAR_NO_ENVIRONMENT(material_postfix, blend_amount, specular)		\
    blend_specular_parameters(											\
		blend_amount,													\
		specular_tint_##material_postfix,								\
		albedo_specular_tint_blend_##material_postfix,                  \
		specular_power_##material_postfix,                              \
		specular_coefficient_##material_postfix,						\
		analytical_specular_contribution_##material_postfix,            \
		area_specular_contribution_##material_postfix,                  \
		fresnel_curve_steepness_##material_postfix,                     \
		specular)

void blend_specular_parameters(
    in float blend_amount,
    in float3 specular_tint,
    in float albedo_specular_tint_blend,
    in float specular_power,
    in float specular_coefficient,
    in float analytical_specular_contribution,
    in float area_specular_contribution,
    in float fresnel_steepness,
    inout specular_parameters specular)
{
    specular.normal_albedo.rgb   += blend_amount * specular_tint * (1.0 - albedo_specular_tint_blend);
    specular.normal_albedo.w     += blend_amount * albedo_specular_tint_blend;

    specular.power               += blend_amount * specular_power;
    specular.analytical          += blend_amount * specular_coefficient * analytical_specular_contribution;         // ###ctchou $PERF can move specular_coefficient outside this blend
    specular.area                += blend_amount * specular_coefficient * area_specular_contribution;

    specular.fresnel_steepness   += blend_amount * fresnel_steepness;
    specular.weight              += blend_amount;
}

#define BLEND_SPECULAR BLEND_SPECULAR_NO_ENVIRONMENT

#endif	// #if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none


void blend_surface_parameters(
    in float2 texcoord,
    in float4 blend,
    out float diffuse_coefficient,
    out specular_parameters specular)
{
    // calculate blended normal and diffuse coefficient
    diffuse_coefficient= 0.0f;

    {
       #if ACTIVE_MATERIAL(material_0_type)
	   //if (blend.x)
       {
         #if SPECULAR_MATERIAL(material_0_type)
          diffuse_coefficient += diffuse_coefficient_m_0 * blend.x;
         #else
          diffuse_coefficient += blend.x;
         #endif
       }
       #endif

       #if ACTIVE_MATERIAL(material_1_type)
	   //if (blend.y)
       {
         #if SPECULAR_MATERIAL(material_1_type)
          diffuse_coefficient += diffuse_coefficient_m_1 * blend.y;
         #else
          diffuse_coefficient += blend.y;
         #endif
       }
       #endif

       #if ACTIVE_MATERIAL(material_2_type)
	   //if (blend.z)
       {
         #if SPECULAR_MATERIAL(material_2_type)
          diffuse_coefficient += diffuse_coefficient_m_2 * blend.z;
         #else
          diffuse_coefficient += blend.z;
         #endif
       }
       #endif

       #if ACTIVE_MATERIAL(material_3_type)
	   //if (blend.w)
       {
         #if SPECULAR_MATERIAL(material_3_type)
          diffuse_coefficient += diffuse_coefficient_m_3 * blend.w;
         #else
          diffuse_coefficient += blend.w;
         #endif
       }
       #endif
    }

    // calculate specular parameters
    specular.normal_albedo= 0.0f;
    specular.power= 0.001f * 1.0f;          // default power is 1.0, default weight is 0.001
    specular.analytical= 0.0f;
    specular.area= 0.0f;

	#if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none
		specular.envmap= 0.0f;
	#endif

    specular.fresnel_steepness= 0.001f * 5.0f;		// default steepness is 5.0
    specular.weight= 0.001f;						// add a teeny bit of initial weight, just to ensure no divide by zero in the final normalization

    #if SPECULAR_MATERIAL_COUNT > 0
    {
       #if SPECULAR_MATERIAL(material_0_type)
         BLEND_SPECULAR(m_0, blend.x, specular);
       #endif

       #if SPECULAR_MATERIAL(material_1_type)
         BLEND_SPECULAR(m_1,    blend.y, specular);
       #endif

       #if SPECULAR_MATERIAL(material_2_type)
         BLEND_SPECULAR(m_2, blend.z, specular);
       #endif

       #if SPECULAR_MATERIAL(material_3_type)
         BLEND_SPECULAR(m_3, blend.w, specular);
       #endif

       // divide out specular weight for 'specular only weighted-blend'
       float scale= 1.0f / specular.weight;
       specular.fresnel_steepness *= scale;
       specular.power *= scale;
    }
    #endif
}

#ifdef PIXEL_SHADER
#ifdef entry_point_lighting

accum_pixel static_lighting_shared_ps_linear_with_dominant_light_fast(
    in struct entry_point_data data,
    in float2 fragment_position,
    in float2 original_texcoord,
    in float3 normal,
    in float3 fragment_to_camera_world,
    in float  extinction,
    in float3 inscatter,
    in float vertex_wetness)
{
    float4 vmf_lighting_coefficients[4];

    get_sh_coefficients(data, vmf_lighting_coefficients);

    // get blend values
    float4 blend= sample_blend_normalized_for_lighting(original_texcoord);

    // calculate blended surface parameters
    float diffuse_coefficient;
    specular_parameters specular;
    blend_surface_parameters(original_texcoord, blend, diffuse_coefficient, specular);

    // normalize interpolated values

	#ifndef ALPHA_OPTIMIZATION
		normal= safe_normalize(normal);
	#endif

    float3 analytical_lighting_direction;
    float3 analytical_lighting_intensity;

    convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world);

	#ifndef pc
		fragment_position.xy+= p_tiling_vpos_offset.xy;
	#endif

    #if DX_VERSION == 11
        float3 bump_normal= normal_texture.Load(int3(fragment_position.xy, 0)).xyz * 2.0f - 1.0f;
	#elif defined(pc)
		float3 bump_normal= sample2D(normal_texture, (fragment_position.xy + float2(0.5f, 0.5f))/texture_size.xy) * 2.0f - 1.0f;
	#else
		float3 bump_normal;
		asm
		{
		   tfetch2D bump_normal.xyz, fragment_position, normal_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
		};
		bump_normal= (bump_normal * 2.0f) - 1.0f;
	#endif

    float3 simple_light_diffuse_light;
    float3 simple_light_specular_light;

	float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
	float3 view_dir= normalize(fragment_to_camera_world);

	#if SPECULAR_MATERIAL_COUNT > 0

		///  DESC: 18 7 2007   13:49 BUNGIE\yaohhu :
		///    do not need normlize, but bump_normal is not normalized. It is possible incorrect before/after optimization.
		float3 view_reflect_dir    = -normalize(reflect(view_dir, bump_normal));

		calc_simple_lights_analytical(
			fragment_position_world,
			bump_normal,
			view_reflect_dir,                              // view direction = fragment to camera,   reflected around fragment normal
			specular.power,
			simple_light_diffuse_light,
			simple_light_specular_light);
	#else
		// Diffuse only materials use diffuse-only simple light calculation
		calc_simple_lights_analytical_diffuse_only(fragment_position_world, bump_normal, simple_light_diffuse_light);
	#endif	// #if SPECULAR_MATERIAL_COUNT > 0

    #if DX_VERSION == 11
        float4 albedo= albedo_texture.Load(int3(fragment_position.xy, 0));
    #elif defined(pc)
		float4 albedo= sample2D(albedo_texture, (fragment_position.xy + float2(0.5f, 0.5f))/texture_size.xy);
	#else
		float4 albedo;
		asm
		{
		   tfetch2D albedo, fragment_position, albedo_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
		};
	#endif

    // if any material is active, evaluate the diffuse lobe

    float4 shadow_mask;
    get_shadow_mask(shadow_mask, fragment_position);
    apply_shadow_mask_to_vmf_lighting_coefficients(shadow_mask, vmf_lighting_coefficients);

    float3 diffuse_light= 0.0f;
    diffuse_light= dual_vmf_diffuse(bump_normal, vmf_lighting_coefficients);
    float3 analytical_mask= get_analytical_mask(fragment_position_world, vmf_lighting_coefficients);
    diffuse_light+= analytical_mask * saturate(dot(analytical_lighting_direction, bump_normal)) * analytical_lighting_intensity / pi * vmf_lighting_coefficients[0].w;

	#if !defined(pc) || (DX_VERSION == 11)
	#ifndef must_be_environment
		diffuse_light+= saturate(dot(k_ps_bounce_light_direction, bump_normal)) * k_ps_bounce_light_intensity;
	#endif
	#endif //!pc

    // if any material is specular, evaluate the combined specular lobe
    float3 analytical_specular_light= 0.0f;
    float3 area_specular_light= 0.0f;
    float3 specular_tint= 0.0f;

    #if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none
		float3 envmap_light= 0.0f;
	#endif

    // mix all light and albedo's together
    float4 out_color;
    out_color.a= 1.0f;

    // compute velocity
    {
       out_color.a= compute_antialias_blur_scalar(fragment_to_camera_world);
    }

    // diffuse light
    out_color.rgb= albedo.rgb * (diffuse_light + simple_light_diffuse_light) * diffuse_coefficient;

	#if SPECULAR_MATERIAL_COUNT > 0

		float specular_contribution_coefficients= specular.analytical + specular.area;

		#if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none
			specular_contribution_coefficients+= specular.envmap;
		#endif

		float specular_test= albedo.w * specular_contribution_coefficients;

		[ifany]
		if (specular_test > 0.0)
		{
			// Compute specular
			float n_dot_v = dot( bump_normal, view_dir );

			calc_phong_outgoing_light(
				bump_normal,
				view_reflect_dir,
				n_dot_v,
				specular.power,
				analytical_lighting_direction,
				analytical_lighting_intensity*analytical_mask,
				analytical_specular_light);

			area_specular_light= dual_vmf_diffuse(view_reflect_dir, vmf_lighting_coefficients);
			area_specular_light= max(0.0f, area_specular_light);

			float3 normal_tint=  lerp(specular.normal_albedo.rgb, albedo.rgb, specular.normal_albedo.w);    // first blend in appropriate amounts of the diffuse albedo
		    float fresnel_blend= pow((1.0f - clamp(n_dot_v, 0.0f, 1.0f)), specular.fresnel_steepness);      //
		    specular_tint=       lerp(normal_tint, float3(1.0f, 1.0f, 1.0f), fresnel_blend);				// then blend that to white at glancing angles

			#if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none	// Only compute environment map contribution if it's actually used.
				float3 enviroment_map_tint= area_specular_light * raised_area_specular_scalar + raised_area_specular_offset;

				envmap_light= CALC_ENVMAP(envmap_type)(
								view_dir,
								bump_normal,
								view_reflect_dir,
								float4(1.0f, 1.0f, 1.0f, max(0.01f, 1.01 - specular.power / 200.0f)),       // convert specular power to roughness (cheap and bad approximation)
								enviroment_map_tint,
								false);
				envmap_light*= shadow_mask.a;
			#endif // #if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none

			float3 specular_contribution= area_specular_light * specular.area + (simple_light_specular_light + analytical_specular_light) * specular.analytical;

			#if ENVMAP_TYPE(envmap_type) != ENVMAP_TYPE_none
				specular_contribution+= envmap_light * specular.envmap;
			#endif

			out_color.rgb += albedo.w * specular_tint * specular_contribution;

		}	// end of if (specular_test > 0.0)
    #endif

	#ifndef NO_WETNESS_EFFECT
		[branch]
		if (ps_boolean_enable_wet_effect)
		{
		   out_color.rgb= calc_wetness_ps(
			 out_color.rgb,
			 view_dir, normal, bump_normal,
			 fragment_to_camera_world, vertex_wetness,
			 vmf_lighting_coefficients, analytical_mask, shadow_mask, albedo.w);
		}
	#endif //NO_WETNESS_EFFECT

    out_color.rgb= (out_color.rgb * extinction + inscatter) * g_exposure.rrr;

    return convert_to_render_target(out_color, true, false);
}
#endif // entry_point_lighting

#if ENTRY_POINT(entry_point) == ENTRY_POINT_static_per_pixel
accum_pixel static_per_pixel_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    CLIP_INPUT
    in float4 texcoord_and_lightmap_uv	: TEXCOORD0,		// xy: regular UVs, zw: lightmap uvs
    in float4 normal_and_extinction		: TEXCOORD1,		// xyz: normal, w: extinction parameter
    in float3 fragment_to_camera_world	: TEXCOORD2,
    in float4 inscatter_wetness			: TEXCOORD3)
{
    entry_point_data data;
    BUILD_ENTRY_POINT_DATA(data);

	return static_lighting_shared_ps_linear_with_dominant_light_fast(
       	data,
       	fragment_position,
       	texcoord_and_lightmap_uv.xy,
       	normal_and_extinction.xyz,
       	fragment_to_camera_world,
       	normal_and_extinction.w,
       	inscatter_wetness.rgb,
       	inscatter_wetness.a);
}
#endif // ENTRY_POINT_static_per_pixel
#endif //PIXEL_SHADER

//===================
// static_per_vertex
//===================
#if ENTRY_POINT(entry_point) == ENTRY_POINT_static_per_vertex
void static_per_vertex_vs(
    in vertex_type vertex,
    #if !defined(pc) || (DX_VERSION == 11)
       in uint vertex_index : SV_VertexID,       // use vertex_index to fetch wetness info
    #endif // !pc
    out float4 position						: SV_Position,
    CLIP_OUTPUT
    out float2 texcoord						: TEXCOORD0,
    out float4 normal_and_extinction		: TEXCOORD1,	// xyz: vertex normal, w: extinction parameter
    out float3 fragment_to_camera_world		: TEXCOORD2,
    out float4 vmf0 						: TEXCOORD3,
    out float4 vmf1 						: TEXCOORD4,
    out float4 vmf2 						: TEXCOORD5,
    out float4 vmf3 						: TEXCOORD6,
    out float4 inscatter_wetness			: COLOR0)
{
    float4 local_to_world_transform_UNUSED[3];
    default_vertex_transform_vs_fast(vertex, position, texcoord, normal_and_extinction.xyz, fragment_to_camera_world, local_to_world_transform_UNUSED);

    float4 vmf_light0;
    float4 vmf_light1;

    int vertex_index_after_offset= vertex_index - per_vertex_lighting_offset.x;
    fetch_stream(vertex_index_after_offset, vmf_light0, vmf_light1);

    decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf0, vmf1, vmf2, vmf3);

    vmf2= float4(normal_and_extinction.xyz,1);

    compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, normal_and_extinction.w);

    // calc wetness
    inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
}

#ifdef PIXEL_SHADER
accum_pixel static_per_vertex_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    CLIP_INPUT
    in float2 original_texcoord			: TEXCOORD0,
    in float4 normal_and_extinction		: TEXCOORD1,	// xyz: vertex normal, w: extinction parameter
    in float3 fragment_to_camera_world	: TEXCOORD2,
    in float4 vmf0 						: TEXCOORD3,
    in float4 vmf1 						: TEXCOORD4,
    in float4 vmf2 						: TEXCOORD5,
    in float4 vmf3 						: TEXCOORD6,
    in float4 inscatter_wetness			: COLOR0)
{
    entry_point_data data;
    BUILD_ENTRY_POINT_DATA(data);

	return static_lighting_shared_ps_linear_with_dominant_light_fast(
       data,
       fragment_position,
       original_texcoord,
       normal_and_extinction.xyz,
       fragment_to_camera_world,
       normal_and_extinction.w,
       inscatter_wetness.rgb,
       inscatter_wetness.a);
}
#endif // PIXEL_SHADER
#endif // ENTRY_POINT_static_per_vertex


//================
// static_sh
//================

#if ENTRY_POINT(entry_point) == ENTRY_POINT_static_sh || ENTRY_POINT(entry_point) == ENTRY_POINT_imposter_static_sh
void static_sh_vs(
    in vertex_type vertex,
    #if !defined(pc) || (DX_VERSION == 11)
       in uint vertex_index : SV_VertexID,       // use vertex_index to fetch wetness info
    #endif // !pc
    out float4 position						: SV_Position,
    CLIP_OUTPUT
    out float2 texcoord						: TEXCOORD0,		// lightmap coordinates are not used by SH pixel shaders
    out float4 normal_and_extinction		: TEXCOORD1,		// xyz: normal, w: extinction parameter
    out float3 fragment_to_camera_world		: TEXCOORD2,
    out float4 inscatter_wetness			: TEXCOORD3)
{
    float4 local_to_world_transform_UNUSED[3];
    default_vertex_transform_vs_fast(vertex, position, texcoord, normal_and_extinction.xyz, fragment_to_camera_world, local_to_world_transform_UNUSED);

    compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, normal_and_extinction.w);

    // calc wetness
    inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
}

#ifdef PIXEL_SHADER
accum_pixel static_sh_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    CLIP_INPUT
    in float2 original_texcoord			: TEXCOORD0,
    in float4 normal_and_extinction		: TEXCOORD1,
    in float3 fragment_to_camera_world	: TEXCOORD2,
    in float4 inscatter_wetness			: TEXCOORD3)
{
    entry_point_data data;
    BUILD_ENTRY_POINT_DATA(data);
    return static_lighting_shared_ps_linear_with_dominant_light_fast(
       			data,
       			fragment_position,
       			original_texcoord,
       			normal_and_extinction.xyz,
       			fragment_to_camera_world,
       			normal_and_extinction.w,
       			inscatter_wetness.rgb,
       			inscatter_wetness.a);
}
#endif  // PIXEL_SHADER
#endif  // ENTRY_POINT_static_sh


//================
// prt_ambient
//================


#if ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_ambient || ENTRY_POINT(entry_point) == ENTRY_POINT_imposter_static_prt_ambient
void static_prt_ambient_vs(
    in vertex_type vertex,
    #if !defined(pc) || (DX_VERSION == 11)
        in uint vertex_index : SV_VertexID,
    #endif // xenon
	#if defined(pc) || (DX_VERSION == 11)
		in float prt_c0_c3 : BLENDWEIGHT1,
	#endif
    out float4 position					: SV_Position,
    CLIP_OUTPUT
    out float2 texcoord					: TEXCOORD0,
    out float4 normal_and_extinction	: TEXCOORD1,
    out float3 fragment_to_camera_world : TEXCOORD2,
    out float4 prt_ravi_diff			: TEXCOORD3,
    out float4 inscatter_wetness		: TEXCOORD4)
{
    float4 local_to_world_transform_UNUSED[3];
    default_vertex_transform_vs_fast(vertex, position, texcoord, normal_and_extinction.xyz, fragment_to_camera_world, local_to_world_transform_UNUSED);

	#if defined(pc) || (DX_VERSION == 11)
		float prt_c0= prt_c0_c3;
	#else // xenon

		// fetch PRT data from compressed
		float prt_c0;

		float prt_fetch_index= vertex_index * 0.25f;                    // divide vertex index by 4
		float prt_fetch_fraction= frac(prt_fetch_index);                   // grab fractional part of index (should be 0, 0.25, 0.5, or 0.75)

		float4 prt_values, prt_component;
		float4 prt_component_match= float4(0.75f, 0.5f, 0.25f, 0.0f);          // bytes are 4-byte swapped (each dword is stored in reverse order)
		asm
		{
		   vfetch    prt_values, prt_fetch_index, blendweight1                 // grab four PRT samples
		   seq       prt_component, prt_fetch_fraction.xxxx, prt_component_match       // set the component that matches to one
		};
		prt_c0= dot(prt_component, prt_values);
	#endif // xenon


    // set prt coeffs to ps
    #if !defined(pc) || (DX_VERSION == 11)
       calc_prt_ravi_diff(prt_c0, vertex.normal, prt_ravi_diff);
    #else
       prt_ravi_diff= 1.0f;
    #endif //!pc

    compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, normal_and_extinction.w);

    // calc wetness
    inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
}
#endif  // ENTRY_POINT_static_prt_quadratic



#if ((ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_quadratic) || (ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_linear) || (ENTRY_POINT(entry_point) == ENTRY_POINT_static_prt_ambient)|| (ENTRY_POINT(entry_point) == ENTRY_POINT_imposter_static_prt_ambient))
#ifdef PIXEL_SHADER
accum_pixel static_prt_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    CLIP_INPUT
    in float2 original_texcoord			: TEXCOORD0,
    in float4 normal_and_extinction		: TEXCOORD1,
    in float3 fragment_to_camera_world	: TEXCOORD2,
    in float4 prt_ravi_diff				: TEXCOORD3,
    in float4 inscatter_wetness			: TEXCOORD4)
{
    entry_point_data data;
    BUILD_ENTRY_POINT_DATA(data);
	return static_lighting_shared_ps_linear_with_dominant_light_fast(
       			data,
       			fragment_position,
       			original_texcoord,
       			normal_and_extinction.xyz,
       			fragment_to_camera_world,
       			normal_and_extinction.w,
       			inscatter_wetness.rgb,
       			inscatter_wetness.a);
}
#endif  // PIXEL_SHADER
#endif  // quadratic / linear / ambient prt ps



PARAM_SAMPLER_2D(dynamic_light_gel_texture);

void default_dynamic_light_vs(
    in vertex_type vertex,
    out float4 position : SV_Position,
    DYNAMIC_LIGHT_CLIP_OUTPUT
    out float2 texcoord : TEXCOORD0,
    out float3 normal : TEXCOORD1,
    out float3 binormal : TEXCOORD2,
    out float3 tangent : TEXCOORD3,
    out float3 fragment_to_camera_world : TEXCOORD4,
    out float4 fragment_position_shadow : TEXCOORD5,
    out float3 extinction : COLOR0,
    out float3 inscatter : COLOR1)          // homogenous coordinates of the fragment position in projective shadow space)
{
    //output to pixel shader
    float4 local_to_world_transform[3];

    //output to pixel shader
    always_local_to_view(vertex, local_to_world_transform, position, binormal);

    texcoord= vertex.texcoord;
    normal= vertex.normal;
    tangent= vertex.tangent;
    // world space vector from vertex to eye/camera
    fragment_to_camera_world= Camera_Position - vertex.position;

    fragment_position_shadow= mul(float4(vertex.position.xyz, 1.0f), Shadow_Projection);

    compute_scattering(Camera_Position, vertex.position, inscatter, extinction.x);
    extinction.yz= 0.0f;

    CALC_DYNAMIC_LIGHT_CLIP(position);
}

#ifdef PIXEL_SHADER
#ifdef entry_point_lighting
accum_pixel default_dynamic_light_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    DYNAMIC_LIGHT_CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3,
    in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 fragment_position_shadow : TEXCOORD5,
    in float3 extinction : COLOR0,
    in float3 inscatter : COLOR1,       // homogenous coordinates of the fragment position in projective shadow space
    bool cinematic,
    bool high_res_shadows)
{
    // get blend values
    float4 blend= sample_blend_normalized_for_lighting(texcoord);

    // calculate blended surface parameters
    float diffuse_coefficient;
    specular_parameters specular;
    blend_surface_parameters(
       texcoord,
       blend,
       diffuse_coefficient,
       specular);

    // normalize interpolated values
    normal= normalize(normal);
    binormal= normalize(binormal);
    tangent= normalize(tangent);

    // setup tangent frame
    float3x3 tangent_frame = {tangent, binormal, normal};

#ifndef pc
    fragment_position.xy+= p_tiling_vpos_offset.xy;
#endif
    // rotate bump normal into world space
#if DX_VERSION == 11
    float3 bump_normal= normal_texture.Load(int3(fragment_position.xy, 0)).xyz * 2.0f - 1.0f;
#elif defined(pc)
    float3 bump_normal= sample2D(normal_texture, (fragment_position.xy + float2(0.5f, 0.5f))/texture_size.xy) * 2.0f - 1.0f;
#else
    float3 bump_normal;
    asm
    {
       tfetch2D bump_normal.xyz, fragment_position, normal_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
    };
    bump_normal= (bump_normal * 2.0f) - 1.0f;
#endif

    // convert view direction to tangent space
    float3 view_dir= normalize(fragment_to_camera_world);
    float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);

    // calculate simple light falloff for expensive light
    float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
    float3 light_radiance;
    float3 fragment_to_light;
    float light_dist2;
    calculate_simple_light(
       0,
       fragment_position_world,
       light_radiance,
       fragment_to_light);         // return normalized direction to the light

    fragment_position_shadow.xyz /= fragment_position_shadow.w;                   // projective transform on xy coordinates

    // apply light gel
    light_radiance *=  sample2D(dynamic_light_gel_texture, transform_texcoord(fragment_position_shadow.xy, p_dynamic_light_gel_xform));

    float4 diffuse_albedo= 1.0f;
    float4 out_color= 0.0f;
    if (dot(light_radiance, light_radiance) > 0.0000001f)                        // ###ctchou $PERF unproven 'performance' hack
    {
       float n_dot_v         = dot( bump_normal, view_dir );

       float3 analytic_diffuse_radiance= 0.0f;
       float3 analytic_specular_radiance= 0.0f;

       // get diffuse albedo and specular mask (specular mask _can_ be stored in the albedo alpha channel, or in a seperate texture)
#if DX_VERSION == 11
       diffuse_albedo= albedo_texture.Load(int3(fragment_position.xy, 0));
#elif defined(pc)
       diffuse_albedo= sample2D(albedo_texture, (fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy);
#else
       asm
       {
         tfetch2D diffuse_albedo, fragment_position, albedo_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
       };
#endif

       // calculate view reflection direction (in world space of course)
       float3 view_reflect_dir= normalize( (dot(view_dir, bump_normal) * bump_normal - view_dir) * 2 + view_dir );

       // calculate diffuse lobe
       analytic_diffuse_radiance= light_radiance * dot(fragment_to_light, bump_normal) * diffuse_albedo.rgb / pi;

       #if SPECULAR_MATERIAL_COUNT > 0
         calc_phong_outgoing_light(
          bump_normal,
          view_reflect_dir,
          n_dot_v,
          specular.power,
          fragment_to_light,
          light_radiance,
          analytic_specular_radiance);
       #endif

       // calculate shadow
       float unshadowed_percentage= 1.0f;

       float cosine= dot(normal.xyz, p_vmf_lighting_constant_1.xyz);                    // p_vmf_lighting_constant_1.xyz = normalized forward direction of light (along which depth values are measured)

       float slope= sqrt(1-cosine*cosine) / cosine;                           // slope == tan(theta) == sin(theta)/cos(theta) == sqrt(1-cos^2(theta))/cos(theta)
//   slope= min(slope, 4.0f) + 0.2f;                                   // don't let slope get too big (results in shadow errors - see master chief helmet), add a little bit of slope to account for curvature
                                                           // ###ctchou $REVIEW could make this (4.0) a shader parameter if you have trouble with the masterchief's helmet not shadowing properly

//   slope= slope / dot(p_vmf_lighting_constant_1.xyz, fragment_to_light.xyz);          // adjust slope to be slope for z-depth

       float half_pixel_size= p_vmf_lighting_constant_1.w * fragment_position_shadow.w;       // the texture coordinate distance from the center of a pixel to the corner of the pixel - increases linearly with increasing depth
       float depth_bias= (slope + 0.2f) * half_pixel_size;

       depth_bias= 0.0f;

       if (cinematic)
       {
           if (high_res_shadows)
           {
                unshadowed_percentage= sample_percentage_closer_PCF_9x9_block_predicated(fragment_position_shadow, depth_bias);
           } else
           {
                unshadowed_percentage= sample_percentage_closer_PCF_5x5_block_predicated(fragment_position_shadow, depth_bias);
           }
       }
       else
       {
           if (high_res_shadows)
           {
                unshadowed_percentage= sample_percentage_closer_PCF_5x5_block_predicated(fragment_position_shadow, depth_bias);
           } else
           {
                unshadowed_percentage= sample_percentage_closer_PCF_3x3_block(fragment_position_shadow, depth_bias);
           }
       }

       // diffuse light
       out_color.rgb= analytic_diffuse_radiance * diffuse_coefficient;

    // specular light
    #if SPECULAR_MATERIAL_COUNT > 0
       // calculate full specular tint
        float3 normal_tint       = lerp(specular.normal_albedo.rgb, diffuse_albedo.rgb, specular.normal_albedo.w);         // first blend in appropriate amounts of the diffuse albedo
       float fresnel_blend       = pow((1.0f - clamp(n_dot_v, 0.0f, 1.0f)), specular.fresnel_steepness);          //
       float3 specular_tint    = lerp(normal_tint, float3(1.0f, 1.0f, 1.0f), fresnel_blend);                 // then blend that to white at glancing angles

       out_color.rgb += diffuse_albedo.w * specular_tint * analytic_specular_radiance * specular.analytical;
    #endif

       out_color.rgb *= unshadowed_percentage;
    }

    // set color channels
    out_color.rgb= out_color.rgb * extinction.x * g_exposure.rrr;         // don't need inscatter because that has been added already in static lighting pass
    out_color.w= 1.0f;

#ifndef NO_WETNESS_EFFECT
    [branch]
    if (ps_boolean_enable_wet_effect)
    {
       float4 vmf_coeffs[4];
       vmf_coeffs[0]= 1;
       vmf_coeffs[1]= 1;
       vmf_coeffs[2]= 1;
       vmf_coeffs[3]= 1;
       out_color.rgb= calc_wetness_ps(
         out_color.rgb,
         view_dir, normal, bump_normal,
         fragment_to_camera_world, 1,
         vmf_coeffs, 1, float4(0.0f, 0.5f, 0.5f, 1.0f), diffuse_albedo.w);
    }
#endif //NO_WETNESS_EFFECT

    return convert_to_render_target(out_color, true, true);
}

accum_pixel dynamic_light_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    DYNAMIC_LIGHT_CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3,
    in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 fragment_position_shadow : TEXCOORD5,
    in float3 extinction : COLOR0,
    in float3 inscatter : COLOR1)       // homogenous coordinates of the fragment position in projective shadow space
{
    return default_dynamic_light_ps(fragment_position, DYNAMIC_LIGHT_CLIP_INPUT_PARAM texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, extinction, inscatter, false, false);
}

accum_pixel dynamic_light_cine_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    DYNAMIC_LIGHT_CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3,
    in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 fragment_position_shadow : TEXCOORD5,
    in float3 extinction : COLOR0,
    in float3 inscatter : COLOR1)       // homogenous coordinates of the fragment position in projective shadow space
{
    return default_dynamic_light_ps(fragment_position, DYNAMIC_LIGHT_CLIP_INPUT_PARAM texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, extinction, inscatter, true, false);
}

accum_pixel dynamic_light_hq_shadows_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    DYNAMIC_LIGHT_CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3,
    in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 fragment_position_shadow : TEXCOORD5,
    in float3 extinction : COLOR0,
    in float3 inscatter : COLOR1)       // homogenous coordinates of the fragment position in projective shadow space
{
    return default_dynamic_light_ps(fragment_position, DYNAMIC_LIGHT_CLIP_INPUT_PARAM texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, extinction, inscatter, false, true);
}

accum_pixel dynamic_light_cine_hq_shadows_ps(
    SCREEN_POSITION_INPUT(fragment_position),
    DYNAMIC_LIGHT_CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float3 normal : TEXCOORD1,
    in float3 binormal : TEXCOORD2,
    in float3 tangent : TEXCOORD3,
    in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 fragment_position_shadow : TEXCOORD5,
    in float3 extinction : COLOR0,
    in float3 inscatter : COLOR1)       // homogenous coordinates of the fragment position in projective shadow space
{
    return default_dynamic_light_ps(fragment_position, DYNAMIC_LIGHT_CLIP_INPUT_PARAM texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, extinction, inscatter, true, true);
}

#endif // entry_point_lighting
#endif //PIXEL_SHADER

#ifdef xdk_2907
[noExpressionOptimizations]
#endif
void lightmap_debug_mode_vs(
    in vertex_type vertex,
    in s_lightmap_per_pixel lightmap,
    out float4 position : SV_Position,
    CLIP_OUTPUT
    out float2 lightmap_texcoord:TEXCOORD0,
    out float3 normal:TEXCOORD1,
    out float2 texcoord:TEXCOORD2,
    out float3 tangent:TEXCOORD3,
    out float3 binormal:TEXCOORD4,
    out float3 fragment_to_camera_world:TEXCOORD5)
{

    float4 local_to_world_transform[3];
    fragment_to_camera_world= Camera_Position-vertex.position;

    //output to pixel shader
    always_local_to_view(vertex, local_to_world_transform, position, binormal);
    lightmap_texcoord= lightmap.texcoord;
    normal= vertex.normal;
    texcoord= vertex.texcoord;
    tangent= vertex.tangent;
    //binormal= vertex.binormal;

	CALC_CLIP(position);
}

#ifdef PIXEL_SHADER

accum_pixel lightmap_debug_mode_ps(
    in float2 lightmap_texcoord:TEXCOORD0,
    in float3 normal:TEXCOORD1,
    in float2 texcoord:TEXCOORD2,
    in float3 tangent:TEXCOORD3,
    in float3 binormal:TEXCOORD4,
    in float3 fragment_to_camera_world:TEXCOORD5) : SV_Target
{
    float4 out_color;

    out_color= display_debug_modes(
       lightmap_texcoord,
       normal,
       texcoord,
       tangent,
       binormal,
       0.0f,
       0.0f,
       0.0f,
       0.0f);

    return convert_to_render_target(out_color, true, false);

}

#endif //PIXEL_SHADER
