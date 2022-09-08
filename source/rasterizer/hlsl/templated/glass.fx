#define blend_type alpha_blend

#include "hlsl_constant_globals.fx"
#include "templated\templated_globals.fx"
#include "templated\analytical_mask.fx"
#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"
#include "templated\albedo.fx"
#include "shared\atmosphere.fx"
#include "templated\bump_mapping.fx"
#include "templated\wetness.fx"
#include "templated\environment_mapping.fx"


// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "templated\velocity.fx"
#include "shared\spherical_harmonics.fx"
#include "templated\lightmap_sampling.fx"
#include "lights\uber_light.fx"
#include "templated\materials\power_roughness_conversion.fx"
#include "lights\simple_lights.fx"
#include "shared\clip_plane.fx"

#define calc_output_color_with_explicit_light_quadratic calc_output_color_with_explicit_light_linear_with_dominant_light

#if defined(entry_point_imposter_static_sh)
	#define static_sh_vs imposter_static_sh_vs
	#define static_sh_ps imposter_static_sh_ps
	#define SHADER_FOR_IMPOSTER
#elif defined(entry_point_imposter_static_prt_ambient)
	#define static_prt_ambient_vs imposter_static_prt_ambient_vs
	#define static_prt_ps imposter_static_prt_ps
	#define SHADER_FOR_IMPOSTER
#endif


PARAM(float, analytical_specular_contribution);
PARAM(float, diffuse_coefficient);
PARAM(float, environment_map_specular_contribution);
PARAM_SAMPLER_2D(material_texture);
PARAM(float4, material_texture_xform);						//texture matrix
PARAM(float, material_texture_black_roughness);
PARAM(float, material_texture_black_specular_multiplier);

PARAM(float, analytical_roughness);

#define area_specular_contribution 0

#define use_material_texture false
#define specular_coefficient 1
#include "templated\materials\two_lobe_phong.fx"

// alias
#define normal_specular		specular_tint
#define glancing_specular	fresnel_color



void get_albedo_and_normal(out float3 bump_normal, out float4 albedo, in float2 texcoord, in float3x3 tangent_frame, in float3 fragment_to_camera_world, in float2 fragment_position)
{
	calc_bumpmap_ps(texcoord, fragment_to_camera_world, tangent_frame, bump_normal);
	calc_albedo_ps(texcoord, albedo, bump_normal);
}

void calc_material_glass_ps(
    in float3 view_dir,
    in float3 fragment_to_camera_world,
    in float3 surface_normal,
    in float3 view_reflect_dir_world,
    in float4 lighting_coefficients[4],
    in float3 analytical_light_dir,
    in float3 analytical_light_intensity,
    in float3 diffuse_reflectance,
    in float  specular_mask,
    in float2 texcoord,
    in float4 prt_ravi_diff,
    in float3x3 tangent_frame,          // = {tangent, binormal, normal};
    inout float3 envmap_area_specular_only,
    out float4 specular_radiance,
    inout float3 diffuse_radiance)
{
	float3 specular_analytical= 0;
	float3 simple_light_diffuse_light= 0.0f;
	float3 simple_light_specular_light= 0.0f;

	float4 spatially_varying_material_parameters;
	float3 normal_specular_blend_albedo_color;
	float3 additional_diffuse_radiance;

	float3 final_specular_tint_color= calc_material_analytic_specular_two_lobe_phong_ps(
		view_dir,
		surface_normal,
		view_reflect_dir_world,
		analytical_light_dir,
		analytical_light_intensity,
		0,
		texcoord,
		prt_ravi_diff.w,
		tangent_frame,
		spatially_varying_material_parameters,
		normal_specular_blend_albedo_color,
		specular_analytical,
		additional_diffuse_radiance);

	[branch]
	if (!no_dynamic_lights)
	{
		float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
		calc_simple_lights_analytical(
			fragment_position_world,
			surface_normal,
			view_reflect_dir_world,                             // view direction = fragment to camera,   reflected around fragment normal
			normal_specular_power,
			simple_light_diffuse_light,
			simple_light_specular_light);
		simple_light_specular_light*=final_specular_tint_color;
	}

	//scaling and masking
	specular_radiance.xyz= specular_mask * (simple_light_specular_light + specular_analytical) * analytical_specular_contribution ;

	envmap_area_specular_only.xyz= envmap_area_specular_only*final_specular_tint_color + 0.25*(lighting_coefficients[1].rgb+lighting_coefficients[3].rgb);

	specular_radiance.w= 0.0f;

	diffuse_radiance= (simple_light_diffuse_light + diffuse_radiance) * diffuse_coefficient;
}

void static_sh_vs(
	in vertex_type vertex,
	#if !defined(pc) || (DX_VERSION == 11)
		in uint vertex_index : SV_VertexID,		// use vertex_index to fetch wetness info
	#endif // !pc

	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float3 texcoord_and_vertexNdotL : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float3 fragment_to_camera_world : TEXCOORD6,
	out float3 extinction : COLOR0,
	out float4 inscatter_wetness : COLOR1)
{
	//output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);

	normal= vertex.normal;
	texcoord_and_vertexNdotL.xy= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	texcoord_and_vertexNdotL.z= dot(normal, v_analytical_light_direction);

	// world space direction to eye/camera
	fragment_to_camera_world.rgb= Camera_Position-vertex.position;

	compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, extinction.x);
	extinction.yz=	0.0f;

	// calc wetness
	inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
} // static_sh_vs


void static_sh_common_vs(
	#if !defined(pc) || (DX_VERSION == 11)
	in uint vertex_index : SV_VertexID,
	#endif // !pc
	in vertex_type vertex,
	out float4 position,
	out float4 texcoord,
	out float wetness,
	out float4 local_to_world_transform[3],
	out float3 fragment_to_camera_world)
{
	float3 normal= vertex.normal;
	texcoord= float4(vertex.texcoord, 0, 1);

	// calc wetness
	wetness= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
}

#if defined(entry_point_lighting)

float4 get_albedo(
	in float2 fragment_position)
{
	float4 albedo;

	{
#ifndef pc
		fragment_position.xy+= p_tiling_vpos_offset.xy;
#endif

#if DX_VERSION == 11
	albedo= albedo_texture.Load(int3(fragment_position.xy, 0));
#elif defined(pc)
		float2 screen_texcoord= (fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy;
		albedo= tex2D(albedo_texture, screen_texcoord);
#else // xenon
		float2 screen_texcoord= fragment_position.xy;
		float4 bump_value;
		asm {
			tfetch2D albedo, screen_texcoord, albedo_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true
		};
#endif // xenon
	}

	return albedo;
}

float4 calc_output_color_with_explicit_light_linear_with_dominant_light(
	float2 fragment_position,
	float3x3 tangent_frame,				// = {tangent, binormal, normal};
	float4 vmf_lighting_coefficients[4],
	float3 fragment_to_camera_world,	// direction to eye/camera, in world space
	float2 original_texcoord,
	float4 prt_ravi_diff,
	float3 light_direction,
	float3 light_intensity,
	float3 extinction,
	float3 inscatter,
	float vertex_wetness)
{
	float4 out_color;

	float3 view_dir= normalize(fragment_to_camera_world);

    float3 bump_normal;
    float4 albedo;
    get_albedo_and_normal(bump_normal, albedo, original_texcoord, tangent_frame, fragment_to_camera_world, float2(0,0));

	float3 view_reflect_dir= -normalize(reflect(view_dir, bump_normal));

	float analytical_light_dot_product_result=saturate(dot(light_direction,bump_normal));
    float raised_analytical_light_equation_a= (raised_analytical_light_maximum-raised_analytical_light_minimum)/2;
    float raised_analytical_light_equation_b= (raised_analytical_light_maximum+raised_analytical_light_minimum)/2;
    float raised_analytical_dot_product= saturate(dot(light_direction, bump_normal)*raised_analytical_light_equation_a+raised_analytical_light_equation_b);
	float3 diffuse_radiance= analytical_light_dot_product_result*
			light_intensity/
			pi*
			vmf_lighting_coefficients[0].w;

	float3 analytical_mask= get_analytical_mask(Camera_Position_PS - fragment_to_camera_world,vmf_lighting_coefficients);

    float3 envmap_area_specular_only= raised_analytical_dot_product * light_intensity * analytical_mask * 0.25f * vmf_lighting_coefficients[2].w;

    const float specular_mask= 1.0;

    float4 envmap_specular_reflectance_and_roughness= float4(environment_map_specular_contribution,
			environment_map_specular_contribution,
			environment_map_specular_contribution,
			analytical_roughness);

    float4 specular_radiance= 0;

    calc_material_glass_ps(
       view_dir,                 // normalized
       fragment_to_camera_world,       // actual vector, not normalized
       bump_normal,              // normalized
       view_reflect_dir,          // normalized

       vmf_lighting_coefficients,
       light_direction,          // normalized
       light_intensity*analytical_mask,

       albedo.xyz,              // diffuse_reflectance
       specular_mask,
       original_texcoord,
       prt_ravi_diff,

       tangent_frame,

       envmap_area_specular_only,
       specular_radiance,
       diffuse_radiance);

	float3 envmap_radiance= CALC_ENVMAP(envmap_type)(view_dir, bump_normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, false);


	// apply opacity fresnel effect
	{
		float final_opacity, specular_scalar;
		calc_alpha_blend_opacity(albedo.w, tangent_frame[2], view_dir, original_texcoord, final_opacity, specular_scalar);

		envmap_radiance*= specular_scalar;
		specular_radiance*= specular_scalar;
		albedo.w= final_opacity;
	}

	out_color.xyz= diffuse_radiance * albedo.xyz + specular_radiance + envmap_radiance;

#ifndef NO_WETNESS_EFFECT
	[branch]
	if (ps_boolean_enable_wet_effect)
	{
		float4 vmf_coeffs[4];
		vmf_coeffs[0]= 1;
		vmf_coeffs[1]= 1;
		vmf_coeffs[2]= 1;
		vmf_coeffs[3]= 1;
		out_color.rgb= calc_wetness_ps(out_color.rgb,
									   0, 0, 0,
									   0, vertex_wetness,
									   vmf_coeffs, 0, float4(0.0f, 0.5f, 0.5f, 1.0f), 0);
	}
#endif //NO_WETNESS_EFFECT
	out_color.w= saturate(albedo.w);

	out_color.rgb= out_color.rgb * g_exposure.rrr;

	return out_color;
}


accum_pixel static_common_ps(
	in float2 fragment_position,
	in float4 texcoord,
	in float3 normal,
	in float4 front_face_lighting,
	in float4 back_face_lighting,
	in float vertex_wetness,
	in float3 fragment_to_camera_world)
{
}




accum_pixel static_sh_ps(
	SCREEN_POSITION_INPUT(fragment_position),
	CLIP_INPUT
	in float3 texcoord_and_vertexNdotL : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float3 fragment_to_camera_world : TEXCOORD6,
	in float3 extinction : COLOR0,						// extinction, desaturation		###ctchou $TODO REMOVE desaturation, clean up the interpolators!
	in float4 inscatter_wetness : COLOR1)
{
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// build lighting_coefficients
	float4 lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0,
			p_vmf_lighting_constant_1,
			p_vmf_lighting_constant_2,
			p_vmf_lighting_constant_3
		};

	float4 prt_ravi_diff= float4(1.0f, 0.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));

	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;

	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world);

	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		lighting_coefficients,
		fragment_to_camera_world,
		texcoord_and_vertexNdotL.xy,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		extinction,
		inscatter_wetness.rgb,
		inscatter_wetness.a);


	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}


//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Single pass rendering entry points
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Common pixel shader for single pass rendering
//-----------------------------------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------------------------------------------------
void static_per_vertex_vs(
 	in vertex_type vertex,
	#if !defined(pc) || (DX_VERSION == 11)
		in uint vertex_index : SV_VertexID,		// use vertex_index to fetch wetness info
	#endif // !pc
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 texcoord : TEXCOORD0,
	out float3 fragment_to_camera_world : TEXCOORD1,
	out float3 tangent : TEXCOORD2,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float4 vmf1 : TEXCOORD5,
	out float3 extinction : COLOR0,
	out float4 inscatter_wetness : COLOR1)
{
	// output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);

	normal= vertex.normal;
	texcoord= vertex.texcoord;
	//binormal= vertex.binormal;
	tangent= vertex.tangent;

	float4 vmf_coefficients[4];

    float4 vmf_light0;
    float4 vmf_light1;

    int vertex_index_after_offset= vertex_index - per_vertex_lighting_offset.x;
    fetch_stream(vertex_index_after_offset, vmf_light0, vmf_light1);

    decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf_coefficients[0], vmf_coefficients[1], vmf_coefficients[2], vmf_coefficients[3]);

    vmf_coefficients[2]= float4(normal,1);

	vmf1.xyz=vmf_coefficients[1]+vmf_coefficients[3];
	vmf1.w=vmf_coefficients[0].w;

	fragment_to_camera_world= Camera_Position-vertex.position;

	compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, extinction.x);
	extinction.yz=	0.0f;

	// calc wetness
	inscatter_wetness.a= 1.0f;

	CALC_CLIP(position);
} // static_per_vertex_vs

accum_pixel static_per_vertex_ps(
	SCREEN_POSITION_INPUT(fragment_position),
	CLIP_INPUT
	in float2 texcoord : TEXCOORD0,
	in float3 fragment_to_camera_world : TEXCOORD1,
	in float3 tangent : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float4 vmf1: TEXCOORD5,
	in float3 extinction : COLOR0,
	in float4 inscatter_wetness : COLOR1)
{

	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	float4 lighting_constants[4];
	lighting_constants[0]=float4(0,0,0,vmf1.w);
	lighting_constants[1]=float4(vmf1.xyz,0);
	lighting_constants[2]=float4(0,0,0,1);
	lighting_constants[3]=0;

	float4 prt_ravi_diff= float4(1.0f, 1.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));

	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;

	convert_uber_light_to_analytical_light(analytical_lighting_direction, analytical_lighting_intensity, fragment_to_camera_world);

	float4 out_color= calc_output_color_with_explicit_light_linear_with_dominant_light(
		fragment_position,
		tangent_frame,
		lighting_constants,
		fragment_to_camera_world,
		texcoord,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		extinction,
		inscatter_wetness.rgb,
		inscatter_wetness.a);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}

accum_pixel static_prt_ps(
	SCREEN_POSITION_INPUT(fragment_position),
	CLIP_INPUT
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float3 fragment_to_camera_world : TEXCOORD6,
	in float3 extinction : COLOR0,
	in float4 inscatter_wetness : COLOR1)
{
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	float4 prt_ravi_diff= float4(1,1,1,1);



	// build lighting_coefficients
	float4 lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0,
			p_vmf_lighting_constant_1,
			p_vmf_lighting_constant_2,
			p_vmf_lighting_constant_3,
		};

	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;

	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world);

	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		lighting_coefficients,
		fragment_to_camera_world,
		texcoord,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		extinction,
		inscatter_wetness.rgb,
		inscatter_wetness.a);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}



void static_prt_ambient_vs(
	in vertex_type vertex,
	#if defined(pc) || (DX_VERSION == 11)
		in float prt_c0_c3 : BLENDWEIGHT1,
	#endif
	#if !defined(pc) || (DX_VERSION == 11)
		in uint vertex_index : SV_VertexID,		// use vertex_index to fetch wetness info
	#endif // !pc

	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float3 fragment_to_camera_world : TEXCOORD6,
	out float3 extinction : COLOR0,
	out float4 inscatter_wetness : COLOR1)
{
#if defined(pc) || (DX_VERSION == 11)
	float prt_c0= prt_c0_c3;
#else // xenon
	// fetch PRT data from compressed
	float prt_c0;

	float prt_fetch_index= vertex_index * 0.25f;								// divide vertex index by 4
	float prt_fetch_fraction= frac(prt_fetch_index);							// grab fractional part of index (should be 0, 0.25, 0.5, or 0.75)

	float4 prt_values, prt_component;
	float4 prt_component_match= float4(0.75f, 0.5f, 0.25f, 0.0f);				// bytes are 4-byte swapped (each dword is stored in reverse order)
	asm
	{
		vfetch	prt_values, prt_fetch_index, blendweight1						// grab four PRT samples
		seq		prt_component, prt_fetch_fraction.xxxx, prt_component_match		// set the component that matches to one
	};
	prt_c0= dot(prt_component, prt_values);
#endif // xenon

	//output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);

	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	// world space direction to eye/camera
	fragment_to_camera_world= Camera_Position-vertex.position;

	compute_scattering(Camera_Position, vertex.position, inscatter_wetness.rgb, extinction.x);
	extinction.yz=	0.0f;

	// calc wetness
	inscatter_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	CALC_CLIP(position);
} // static_prt_ambient_vs


#endif // defined(entry_point_lighting)