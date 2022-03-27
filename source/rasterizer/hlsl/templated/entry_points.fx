
#include "templated\analytical_mask.fx"
#include "lights\uber_light.fx"

#ifndef pc
#define ALPHA_OPTIMIZATION
#endif

#ifndef PRE_SHADER
#define PRE_SHADER(texcoord)
#endif // PRE_SHADER

#ifndef APPLY_OVERLAYS
#define APPLY_OVERLAYS(color, texcoord, view_dot_normal)
#endif // APPLY_OVERLAYS

#if defined(entry_point_single_pass_per_pixel)
	#define SINGLE_PASS_LIGHTING_ENTRY_POINT
	#define SINGLE_PASS_LIGHTING
	#define static_per_pixel_ps single_pass_per_pixel_ps
	#define static_per_pixel_vs single_pass_per_pixel_vs
#elif defined(entry_point_single_pass_per_vertex)
	#define	SINGLE_PASS_LIGHTING_ENTRY_POINT	
	#define SINGLE_PASS_LIGHTING
	#define static_per_vertex_ps single_pass_per_vertex_ps
	#define static_per_vertex_vs single_pass_per_vertex_vs
#elif defined(entry_point_single_pass_single_probe)
	#define	SINGLE_PASS_LIGHTING_ENTRY_POINT		
	#define SINGLE_PASS_LIGHTING
#elif defined(entry_point_single_pass_single_probe_ambient)
	#define	SINGLE_PASS_LIGHTING_ENTRY_POINT	
	#define SINGLE_PASS_LIGHTING
#elif defined(entry_point_dynamic_light)
	// should do this but we run out of registers
	// #define	SINGLE_PASS_LIGHTING	
#elif defined(entry_point_dynamic_light_cinematic)
	// should do this but we run out of registers
	// #define	SINGLE_PASS_LIGHTING	
#elif defined(entry_point_imposter_static_sh)
	#define static_sh_vs imposter_static_sh_vs
	#define static_sh_ps imposter_static_sh_ps
	#define SHADER_FOR_IMPOSTER
#elif defined(entry_point_imposter_static_prt_ambient)
	#define static_prt_ambient_vs imposter_static_prt_ambient_vs
	#define static_prt_ps imposter_static_prt_ps
	#define SHADER_FOR_IMPOSTER
#else

#endif

#ifdef SINGLE_PASS_LIGHTING_ENTRY_POINT
#define ACCUM_PIXEL accum_pixel_and_normal
#else
#define ACCUM_PIXEL accum_pixel
#endif // SINGLE_PASS_LIGHTING_ENTRY_POINT

#include "shadows\shadow_mask.fx"
#include "shared\constants.fx"

// disable imposter capture by default
#define k_boolean_enable_imposter_capture_place_holder false

#if defined(PIXEL_SHADER) && defined(xenon)
	#undef k_boolean_enable_imposter_capture_place_holder
	
	#ifdef SHADER_FOR_IMPOSTER
		#define k_boolean_enable_imposter_capture_place_holder k_boolean_enable_imposter_capture
	#else
		#define k_boolean_enable_imposter_capture_place_holder false
	#endif

#endif //defined(PIXEL_SHADER) && defined(xenon)


sampler radiance_map;
sampler dynamic_light_gel_texture;
//float4 dynamic_light_gel_texture_xform;		// no way to extern this, so I replace it with p_dynamic_light_gel_xform which is aliased on p_vmf_lighting_constant_4

float approximate_specular_type;

const float foliage_translucency_input= 0.3f;	

#ifdef SCOPE_TRANSPARENTS

#else

#define interpolated_inscatter_extinction float4(0,0,0,1)

#endif


void get_albedo_and_normal(out float3 bump_normal, out float4 albedo, in float2 texcoord, in float3x3 tangent_frame, in float3 fragment_to_camera_world, in float2 fragment_position)
{
#ifdef SINGLE_PASS_LIGHTING	

	calc_bumpmap_ps(texcoord, fragment_to_camera_world, tangent_frame, bump_normal);
	calc_albedo_ps(texcoord, albedo, bump_normal);	
	albedo= saturate(albedo);
	
#ifdef BLEND_MODE_OFF	
	integrate_analytcial_mask(albedo, analytical_specular_contribution);
	albedo= saturate(albedo);
#endif // BLEND_MODE_OFF

#else // !SINGLE_PASS_LIGHTING

	{
	#ifndef pc
		fragment_position.xy+= p_tiling_vpos_offset.xy;
	#endif

	#ifdef pc
		float2 screen_texcoord= (fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy;
		bump_normal= tex2D(normal_texture, screen_texcoord).xyz * 2.0f - 1.0f;
		albedo= tex2D(albedo_texture, screen_texcoord);
	#else // xenon
		float2 screen_texcoord= fragment_position.xy;
		float4 bump_value;
		asm {
			tfetch2D bump_value, screen_texcoord, normal_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
			tfetch2D albedo, screen_texcoord, albedo_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true
		};
		
		bump_normal= bump_value.xyz * 2.0f - 1.0f;
	#endif // xenon
	}

#endif //SINGLE_PASS_LIGHTING
}


#define static_default_vs	albedo_vs		// use same shader

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void albedo_vs(
#if defined(_standard_vs)
	in vertex_type vertex,
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4)
#endif
{	
#if defined(_standard_vs)
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	// normal, tangent and binormal are all in world space
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;

#elif defined(_xenon_tessellation_pre_pass_vs)
	vertex_type vertex;
	float4 local_to_world_transform[3];	
	deform(vertex_index, vertex, local_to_world_transform);	
		
	// output
	memory_export_geometry_to_stream(vertex_index, vertex, 0);
	memory_export_flush();

#elif defined(_xenon_tessellation_post_pass_vs)
	s_shader_cache_vertex vertex;	

	blend_cache_geometry_by_indices(indices, vertex, position);

	// normal, tangent and binormal are all in world space
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;

#endif 
} // albedo_vs

#undef static_default_vs

albedo_pixel albedo_ps(
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4)
{
	// normalize interpolated values	
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif

	float3 view_dir= normalize(fragment_to_camera_world.xyz);
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};
	
	// convert view direction from world space to tangent space
	float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);

	// run pre-shader operations (used for material blending modes)
	PRE_SHADER(original_texcoord);
	
	// compute parallax
	float2 texcoord= 0;
#ifndef SINGLE_PASS_LIGHTING	
#if ALPHA_TEST(alpha_test) == ALPHA_TEST_on
	if (always_true)
#endif
#endif
	{
		calc_parallax_ps(original_texcoord, view_dir_in_tangent_space, texcoord);

		// alpha test
		calc_alpha_test_ps(texcoord);
	}
	
   	// compute the bump normal in world_space
	float3 bump_normal;
	calc_bumpmap_ps(texcoord, fragment_to_camera_world, tangent_frame, bump_normal);
	
	float4 albedo;
	calc_albedo_ps(texcoord, albedo, bump_normal);
#ifdef BLEND_MODE_OFF	
	integrate_analytcial_mask(albedo, analytical_specular_contribution);
#endif
	
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_diffuse_only	
	albedo.a= 0;
#elif MATERIAL_TYPE(material_type) == MATERIAL_TYPE_foliage
	albedo.a= 0;
#endif

#ifndef NO_ALPHA_TO_COVERAGE
//	albedo.w= output_alpha;
#endif

	return convert_to_albedo_target(albedo, bump_normal, approximate_specular_type);
}

accum_pixel static_default_ps(
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4)
{
	albedo_pixel result= albedo_ps(texcoord, normal, binormal, tangent, fragment_to_camera_world);
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(result.albedo_specmask, true, false);
}

float4 calc_output_color_with_explicit_light_quadratic(
	float2 fragment_position,
	float3x3 tangent_frame,				// = {tangent, binormal, normal};
	float4 lighting_coefficients[4],
	float3 fragment_to_camera_world,	// direction to eye/camera, in world space
	float2 original_texcoord,
	float4 prt_ravi_diff,
	float3 light_direction,
	float3 light_intensity,
	float extinction,
	float3 inscatter,
	float vertex_wetness,
	out float3 bump_normal)
{
	// hack the lighting for imposter capture only
#ifdef xenon
	float imposter_diffuse_contribution= 1.0f;
	float imposter_specular_contribution= 1.0f;
	float imposter_envmap_contribution= 1.0f;
	float imposter_emission_contribution= 1.0f;

	[branch]
	if (k_boolean_enable_imposter_capture_place_holder)
	{
		const float4 shading_component_controls= lighting_coefficients[2];
		imposter_diffuse_contribution= shading_component_controls.x;
		imposter_specular_contribution= shading_component_controls.y;
		imposter_envmap_contribution=  shading_component_controls.z;
		imposter_emission_contribution= shading_component_controls.w;

		const float3 local_view_direction= lighting_coefficients[0];
		const float3 local_light_direction= light_direction;

		// transform view/light to world space
		fragment_to_camera_world= 
			tangent_frame[0]*local_view_direction.x +
			tangent_frame[1]*local_view_direction.y +
			tangent_frame[2]*local_view_direction.z;

		light_direction= 
			tangent_frame[0]*local_light_direction.x +
			tangent_frame[1]*local_light_direction.y +
			tangent_frame[2]*local_light_direction.z;
		light_direction= normalize(light_direction);

		lighting_coefficients[0].xyz= light_direction;
	}
#endif // xenon

	float3 view_dir= normalize(fragment_to_camera_world);

	// convert view direction to tangent space
	float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);
	
	// run pre-shader operations (used for material blending modes)
	PRE_SHADER(original_texcoord);
	
	// compute parallax
	float2 texcoord= 0;
#ifndef SINGLE_PASS_LIGHTING	
#if ALPHA_TEST(alpha_test) == ALPHA_TEST_on
	if (always_true)
#endif
#endif
	{
		calc_parallax_ps(original_texcoord, view_dir_in_tangent_space, texcoord);

		// do alpha test
		calc_alpha_test_ps(texcoord);
	}

	// get diffuse albedo, specular mask and bump normal
	float4 albedo;	
	get_albedo_and_normal(bump_normal, albedo, texcoord, tangent_frame, fragment_to_camera_world, fragment_position);
	restore_specular_mask(albedo, analytical_specular_contribution);
	
	// normalize bump to make sure specular is smooth as a baby's bottom	
	float normal_lengthsq= dot(bump_normal.xyz, bump_normal.xyz);
	bump_normal /= sqrt(normal_lengthsq);	

	float specular_mask;
	calc_specular_mask_ps(texcoord, albedo.w, specular_mask);
	
	// calculate view reflection direction (in world space of course)
	float view_dot_normal=	dot(view_dir, bump_normal);
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	/// float3 view_reflect_dir= normalize( (view_dot_normal * bump_normal - view_dir) * 2 + view_dir );
	float3 view_reflect_dir= (view_dot_normal * bump_normal - view_dir) * 2 + view_dir;

	float4 envmap_specular_reflectance_and_roughness;
	float3 envmap_area_specular_only;
	float4 specular_radiance;
	
	float4 vmf_lighting_coefficients[4]= {
	    lighting_coefficients[0], 
	    lighting_coefficients[1], 
	    lighting_coefficients[2], 
	    lighting_coefficients[3]
	    };
	    
#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_foliage	
    // limit the prt. the vertex can be burried deep in transparent polygons. But it should still be bright.
	prt_ravi_diff=lerp(0.7f,1,prt_ravi_diff);
#endif	

	float4 shadow_mask= 0;
	float3 analytical_mask= 0;
	float3 diffuse_radiance= 0;
		
	{    
		get_shadow_mask(shadow_mask, fragment_position);
		apply_shadow_mask_to_vmf_lighting_coefficients(shadow_mask, vmf_lighting_coefficients);		
	    
		diffuse_radiance=  dual_vmf_diffuse(bump_normal, vmf_lighting_coefficients);
		
		analytical_mask= get_analytical_mask(Camera_Position_PS - fragment_to_camera_world,vmf_lighting_coefficients);
		
	#if MATERIAL_TYPE(material_type) != MATERIAL_TYPE_foliage	
		float analytical_light_dot_product_result=saturate(dot(light_direction,bump_normal));
		
	//	float cosine=	saturate(dot(light_direction,bump_normal) * 0.5f + 0.5f);
	//	cosine *= cosine;
	//	float analytical_light_dot_product_result=cosine*cosine;
		
	#else
		float analytical_light_dot_product_result= foliage_dot_product(light_direction, bump_normal, foliage_translucency_input);
	#endif	    

		const float raised_analytical_light_equation_a= (raised_analytical_light_maximum-raised_analytical_light_minimum)/2;
		const float raised_analytical_light_equation_b= (raised_analytical_light_maximum+raised_analytical_light_minimum)/2;
		float raised_analytical_dot_product= saturate(dot(light_direction, bump_normal)*raised_analytical_light_equation_a+raised_analytical_light_equation_b);

	#ifdef xenon	
		if ( ! k_boolean_enable_imposter_capture_place_holder)
		{		
			diffuse_radiance+= analytical_mask*analytical_light_dot_product_result*
				light_intensity/
				pi*
				vmf_lighting_coefficients[0].w;
		}
	#endif //xenon


	#ifndef pc
	#ifndef must_be_environment
		diffuse_radiance+= saturate(dot(k_ps_bounce_light_direction, bump_normal))*k_ps_bounce_light_intensity/pi;
	#endif
	#endif //pc

		// prebake analytical tint
		envmap_area_specular_only= raised_analytical_dot_product * light_intensity * analytical_mask * 0.25f * lighting_coefficients[2].w * prt_ravi_diff.z;

	}
	
	CALC_MATERIAL(material_type)(
		view_dir,						// normalized
		fragment_to_camera_world,		// actual vector, not normalized
		bump_normal,					// normalized
		view_reflect_dir,				// normalized
		
		lighting_coefficients,	
		light_direction,				// normalized
		light_intensity*analytical_mask,
		
		albedo.xyz,					// diffuse_reflectance
		specular_mask,
		texcoord,
		prt_ravi_diff,

		tangent_frame,

		envmap_specular_reflectance_and_roughness,
		envmap_area_specular_only,
		specular_radiance,
		diffuse_radiance);
		
	envmap_area_specular_only= max(envmap_area_specular_only, 0.001f) * shadow_mask.a;
	float3 envmap_radiance= CALC_ENVMAP(envmap_type)(view_dir, bump_normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, k_boolean_enable_imposter_capture_place_holder);

	//compute self illumination	
	float3 self_illum_radiance= calc_self_illumination_ps(texcoord, albedo.xyz, view_dir_in_tangent_space, fragment_position, fragment_to_camera_world, view_dot_normal) * ILLUM_SCALE;

	// compute velocity
	float output_alpha;
	{
		output_alpha= compute_antialias_blur_scalar(fragment_to_camera_world);
	}

	// apply opacity fresnel effect	
	{
		float final_opacity, specular_scalar;
		calc_alpha_blend_opacity(albedo.w, tangent_frame[2], view_dir, texcoord, final_opacity, specular_scalar);

		envmap_radiance*= specular_scalar;
		specular_radiance*= specular_scalar;
		albedo.w= final_opacity;
	}

#ifdef xenon
	[branch]
	if (k_boolean_enable_imposter_capture_place_holder)
	{
		diffuse_radiance*= imposter_diffuse_contribution;
		specular_radiance*= imposter_specular_contribution;
		envmap_radiance*= imposter_envmap_contribution;
		self_illum_radiance*= imposter_emission_contribution;
	}
#endif //xenon
	
	float4 out_color;
	
	// set color channels
#ifdef BLEND_MULTIPLICATIVE
	out_color.xyz= (albedo.xyz + self_illum_radiance);		// No lighting, no fog, no exposure
	APPLY_OVERLAYS(out_color.xyz, texcoord, view_dot_normal)
	out_color.xyz= out_color.xyz * BLEND_MULTIPLICATIVE;
	out_color.w= ALPHA_CHANNEL_OUTPUT;

#else
	out_color.xyz= (diffuse_radiance * albedo.xyz + specular_radiance + self_illum_radiance + envmap_radiance);
	APPLY_OVERLAYS(out_color.xyz, texcoord, view_dot_normal)
	#ifndef NO_WETNESS_EFFECT		
		if (ps_boolean_enable_wet_effect)
		{				
			out_color.xyz= calc_wetness_ps(
				out_color.xyz, 
				view_dir, tangent_frame[2], bump_normal, 
				fragment_to_camera_world, vertex_wetness, 
				vmf_lighting_coefficients, 
				analytical_mask, shadow_mask, albedo.w);
		}
	#endif //NO_WETNESS_EFFECT
	out_color.xyz= (out_color.xyz * extinction.x + inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
#endif
	
	return out_color;
}
	


///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void static_per_pixel_vs(
	in vertex_type vertex,
	in s_lightmap_per_pixel lightmap,
	#ifndef pc	
		in float vertex_index : INDEX,		// use vertex_index to fetch wetness info
	#endif // !pc
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float2 lightmap_texcoord : TEXCOORD6,
	out float4 fragment_to_camera_world_wetness : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	out float4 inscatter_extinction: COLOR0
#endif
)

{
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	lightmap_texcoord= lightmap.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	// world space direction to eye/camera
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;

#ifdef SCOPE_TRANSPARENTS
	compute_scattering(Camera_Position, vertex.position, inscatter_extinction.rgb, inscatter_extinction.w);	
#endif

	// calc wetness
	fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

} // static_per_pixel_vs


#include "templated\lightmap_sampling.fx"

ACCUM_PIXEL static_per_pixel_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float2 lightmap_texcoord : TEXCOORD6,
	in float4 fragment_to_camera_world_wetness : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction : COLOR0
#endif
	) : COLOR	
{
	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif

	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};
	
	float4 vmf_coefficients[4];

	sample_lightprobe_texture(
		lightmap_texcoord,
		vmf_coefficients);
				
	float4 prt_ravi_diff= float4(1.0f, 1.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));
	
	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;
	
	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world_wetness.xyz);
	
	float3 bump_normal;
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		vmf_coefficients,
		fragment_to_camera_world_wetness.xyz,
		texcoord,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		interpolated_inscatter_extinction.w,
		interpolated_inscatter_extinction.rgb,
		fragment_to_camera_world_wetness.a,
		bump_normal);

#ifdef SINGLE_PASS_LIGHTING_ENTRY_POINT
	return convert_to_render_target(out_color, bump_normal, 1.0f, false, false);
#else
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, false, false);
#endif
}

///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void static_sh_vs(
#if defined(_standard_vs)
	in vertex_type vertex,
	#ifndef pc	
		in float vertex_index : INDEX,		// use vertex_index to fetch wetness info
	#endif // !pc
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float3 texcoord_and_vertexNdotL : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float4 fragment_to_camera_world_wetness : TEXCOORD6
#ifdef SCOPE_TRANSPARENTS	
	,
	out float4 inscatter_extinction : COLOR0
#endif
	)
#endif
{
#if defined(_standard_vs)
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
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;	

#ifdef SCOPE_TRANSPARENTS
	compute_scattering(Camera_Position, vertex.position, inscatter_extinction.rgb, inscatter_extinction.w);	
#endif
	
	// calc wetness
	fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

#elif defined(_xenon_tessellation_pre_pass_vs)
	vertex_type vertex;
	float4 local_to_world_transform[3];	
	deform(vertex_index, vertex, local_to_world_transform);	

	float n_dot_l;
	n_dot_l= dot(vertex.normal, v_analytical_light_direction);
	
	// output	
	memory_export_geometry_to_stream(vertex_index, vertex, n_dot_l);	

	memory_export_flush();

#elif defined(_xenon_tessellation_post_pass_vs)
	s_shader_cache_vertex vertex;	
	blend_cache_geometry_by_indices(indices, vertex, position);	
	
	normal= vertex.normal;
	texcoord_and_vertexNdotL.xy= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;	

	texcoord_and_vertexNdotL.z= vertex.light_param.x;
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;
	fragment_to_camera_world_wetness.a= 0;

#ifdef SCOPE_TRANSPARENTS	
	inscatter_extinction= float4(0,0,0,1);
#endif

#endif 
} // static_sh_vs


ACCUM_PIXEL static_sh_ps(
	in float2 fragment_position : VPOS,
	in float3 texcoord_and_vertexNdotL : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float4 fragment_to_camera_world_wetness : TEXCOORD6
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction: COLOR0
#endif
	)
{
	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// build lighting_coefficients
	float4 lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0, 
			p_vmf_lighting_constant_1, 
			p_vmf_lighting_constant_2, 
			p_vmf_lighting_constant_3, 
		}; 	

	float4 prt_ravi_diff= float4(1.0f, 0.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));
	
	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;
	
	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world_wetness.xyz);
	
	float3 bump_normal;
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		lighting_coefficients,
		fragment_to_camera_world_wetness.xyz,
		texcoord_and_vertexNdotL.xy,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		interpolated_inscatter_extinction.w,
		interpolated_inscatter_extinction.rgb,
		fragment_to_camera_world_wetness.a,
		bump_normal);

#ifdef SINGLE_PASS_LIGHTING_ENTRY_POINT
	return convert_to_render_target(out_color, bump_normal, 1.0f, false, false);
#else
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, false, false);	
#endif // SINGLE_PASS_LIGHTING_ENTRY_POINT
}


//
// single_pass_single_probe
//
#ifndef pc	

void single_pass_single_probe_vs(
#if defined(_standard_vs)
	in vertex_type vertex,		
	in float vertex_index : INDEX,		// use vertex_index to fetch wetness info		
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float3 texcoord_and_vertexNdotL : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float4 fragment_to_camera_world_wetness : TEXCOORD6
	
#ifdef SCOPE_TRANSPARENTS
	,
	out float4 inscatter_extinction: COLOR0
#endif
	)
#endif
{
#if defined(_xenon_tessellation_pre_pass_vs)
#ifdef SCOPE_TRANSPARENTS
	float4 inscatter_extinction;
#endif
#endif

#if defined(_standard_vs)
	static_sh_vs(
		vertex, vertex_index, 
		position, texcoord_and_vertexNdotL, 
		normal, binormal, tangent, fragment_to_camera_world_wetness
#ifdef SCOPE_TRANSPARENTS		
		,inscatter_extinction
#endif

);		

#elif defined(_xenon_tessellation_pre_pass_vs)
	static_sh_vs(vertex_index);		

#elif defined(_xenon_tessellation_post_pass_vs)
	static_sh_vs(
		indices, 
		position, texcoord_and_vertexNdotL, 
		normal, binormal, tangent, fragment_to_camera_world_wetness
#ifdef SCOPE_TRANSPARENTS		
		, inscatter_extinction
#endif
		);				
#endif 
} // single_pass_single_probe_vs

ACCUM_PIXEL single_pass_single_probe_ps(
	in float2 fragment_position : VPOS,
	in float3 texcoord_and_vertexNdotL : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float4 fragment_to_camera_world_wetness : TEXCOORD6
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction: COLOR0
#endif
	)
{
	return static_sh_ps(
		fragment_position, texcoord_and_vertexNdotL,
		normal, binormal, tangent,
		fragment_to_camera_world_wetness
#ifdef SCOPE_TRANSPARENTS
		,interpolated_inscatter_extinction
#endif
		);
}
#endif // !pc



///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void static_per_vertex_vs(
    in vertex_type vertex,
    #ifndef pc  
       in float vertex_index : INDEX,       // use vertex_index to fetch wetness info
    #endif // !pc
    out float4 position : POSITION,
    out float2 texcoord : TEXCOORD0,
    out float4 fragment_to_camera_world_wetness : TEXCOORD1,
    out float3 tangent : TEXCOORD2,
    out float3 normal : TEXCOORD3,    
    out float3 binormal : TEXCOORD4,
    out float4 vmf0 : TEXCOORD5,
    out float4 vmf1 : TEXCOORD6,
    out float4 vmf2 : TEXCOORD7,
    out float4 vmf3 : TEXCOORD8
#ifdef SCOPE_TRANSPARENTS
	,
    out float4 inscatter_extinction: COLOR0
#endif
    )
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
    
    decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf0, vmf1, vmf2, vmf3);
    
    vmf2= float4(normal,1);
    
    fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;
    
#ifdef SCOPE_TRANSPARENTS
	compute_scattering(Camera_Position, vertex.position, inscatter_extinction.rgb, inscatter_extinction.w);	
#endif

    // calc wetness
    fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

} // static_per_vertex_vs


ACCUM_PIXEL static_per_vertex_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float4 fragment_to_camera_world_wetness : TEXCOORD1,
	in float3 tangent : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float4 vmf0: TEXCOORD5,
	in float4 vmf1: TEXCOORD6,
	in float4 vmf2: TEXCOORD7,
	in float4 vmf3: TEXCOORD8
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction: COLOR0
#endif
	)
{
//	float3 view_dir= normalize(fragment_to_camera_world_wetness.xyz);		// world space direction to eye/camera

	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
//	float3 tangent= normalize(cross(binormal, normal));
	tangent= normalize(tangent);
#endif

	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};
	
	float4 lighting_constants[4];
	lighting_constants[0]=vmf0;
	lighting_constants[1]=vmf1;
	lighting_constants[2]=vmf2;
	lighting_constants[3]=vmf3;

	float4 prt_ravi_diff= float4(1.0f, 1.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));
	
	float3 analytical_lighting_direction;
	float3 analytical_lighting_intensity;
	
	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world_wetness.xyz);
	
	float3 bump_normal;
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		lighting_constants,
		fragment_to_camera_world_wetness.xyz,
		texcoord,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		interpolated_inscatter_extinction.a,
		interpolated_inscatter_extinction.rgb,
		fragment_to_camera_world_wetness.a,
		bump_normal);

#ifdef SINGLE_PASS_LIGHTING_ENTRY_POINT
	return convert_to_render_target(out_color, bump_normal, 1.0f, false, false);
#else
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, false, false);	
#endif
}

//straight vert color
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif


void static_per_vertex_color_vs(
	in vertex_type vertex,
	in float3 vert_color				: TEXCOORD3,
	#ifndef pc	
		in float vertex_index : INDEX,		// use vertex_index to fetch wetness info
	#endif // !pc
	out float4 position					: POSITION,
	out float2 texcoord					: TEXCOORD0,
	out float3 out_color				: TEXCOORD1,
	out float4 fragment_to_camera_world_wetness : TEXCOORD2,
	out float3 normal					: TEXCOORD3,
	out float3 binormal					: TEXCOORD4,
	out float3 tangent					: TEXCOORD5
#ifdef SCOPE_TRANSPARENTS
	,
	out float4 inscatter_extinction: COLOR0
#endif
	)
{
	// output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;		// world space direction to eye/camera
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	//binormal= vertex.binormal;
	tangent= vertex.tangent;
	out_color= vert_color;	
	
#ifdef SCOPE_TRANSPARENTS
	compute_scattering(Camera_Position, vertex.position, inscatter_extinction.rgb, inscatter_extinction.w);	
#endif

	// calc wetness
	fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

} // static_per_vertex_color_vs



accum_pixel static_per_vertex_color_ps(
	in float2 fragment_position			: VPOS,
	in float2 texcoord					: TEXCOORD0,
	in float3 vert_color				: TEXCOORD1,
	in float4 fragment_to_camera_world_wetness	: TEXCOORD2,
	in float3 normal					: TEXCOORD3,
	in float3 binormal					: TEXCOORD4,
	in float3 tangent					: TEXCOORD5
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction: COLOR0
#endif
	)
{	
	// normalize interpolated values
	normal= normalize(normal);

	// run pre-shader operations (used for material blending modes)
	PRE_SHADER(texcoord);

	// no parallax?

	// do alpha test
	calc_alpha_test_ps(texcoord);
	
	// get diffuse albedo, specular mask and bump normal
	float4 albedo;	
#ifdef SINGLE_PASS_LIGHTING
	calc_albedo_ps(texcoord, albedo, normal);
#ifdef BLEND_MODE_OFF	
	integrate_analytcial_mask(albedo, analytical_specular_contribution);
#endif

#else	
#ifndef pc
	fragment_position.xy+= p_tiling_vpos_offset.xy;
#endif
	float2 screen_texcoord= (fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy;
	albedo= tex2D(albedo_texture, screen_texcoord);

#endif //SINGLE_PASS_LIGHTING


	float3 view_dir= normalize(fragment_to_camera_world_wetness.xyz);
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};
	
	// convert view direction to tangent space
	float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);
	
	//compute self illumination	
	float3 self_illum_radiance= calc_self_illumination_ps(texcoord, albedo.xyz, view_dir_in_tangent_space, fragment_position, fragment_to_camera_world_wetness.xyz, 1.0f) * ILLUM_SCALE;
	
	float3 simple_light_diffuse_light;
	float3 simple_light_specular_light;
	float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world_wetness.xyz;
	calc_simple_lights_analytical(
		fragment_position_world,
		normal,
		float3(1.0f, 0.0f, 0.0f),										// view reflection direction (not needed cuz we're doing diffuse only)
		1.0f,
		simple_light_diffuse_light,
		simple_light_specular_light);
	
	// compute velocity
	float output_alpha;
	{
		output_alpha= compute_antialias_blur_scalar(fragment_to_camera_world_wetness.xyz);
	}
	
	// set color channels
	float4 out_color;
#ifdef BLEND_MULTIPLICATIVE
	out_color.xyz= (vert_color * albedo.xyz + self_illum_radiance) * BLEND_MULTIPLICATIVE;		// No lighting, no fog, no exposure
#else
	out_color.xyz= ((vert_color + simple_light_diffuse_light) * albedo.xyz  + self_illum_radiance);
	out_color.xyz= (out_color.xyz * interpolated_inscatter_extinction.a + interpolated_inscatter_extinction.rgb * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
#endif
	//out_color.xyz= vert_color * g_exposure.rgb;
	out_color.w= ALPHA_CHANNEL_OUTPUT;

		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}


#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void static_prt_ambient_vs(
#if defined(_standard_vs)
	in vertex_type vertex,
	#ifndef pc	
		in float vertex_index : INDEX,		// use vertex_index to fetch wetness info
	#endif // !pc
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float4 fragment_to_camera_world_wetness : TEXCOORD6,
	out float4 prt_ravi_diff : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	out float4 inscatter_extinction: COLOR0
#endif
	)
#endif
{
#if defined(_standard_vs)
#ifdef pc
	float prt_c0= PRT_C0_DEFAULT;
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
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;
	
	// calc prt coeffs
	#ifndef pc
		calc_prt_ravi_diff(prt_c0, vertex.normal, prt_ravi_diff);
	#else
		prt_ravi_diff= 1.0f;
	#endif //!pc
	
#ifdef SCOPE_TRANSPARENTS
	compute_scattering(Camera_Position, vertex.position, inscatter_extinction.rgb, inscatter_extinction.w);	
#endif

	// calc wetness
	fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	
#elif defined(_xenon_tessellation_pre_pass_vs)
	vertex_type vertex;
	float4 local_to_world_transform[3];	
	deform(vertex_index, vertex, local_to_world_transform);	
	
	float4 prt_ravi_diff= 1.0f;
	{
		float prt_c0;
		light_fetch_prt_ambient(vertex_index, prt_c0);		
		#ifndef pc
			calc_prt_ravi_diff(prt_c0, vertex.normal, prt_ravi_diff);
		#else
			prt_ravi_diff= 1.0f;
		#endif //!pc
	}

	// output	
	memory_export_geometry_to_stream(vertex_index, vertex, prt_ravi_diff);	
	memory_export_flush();

#elif defined(_xenon_tessellation_post_pass_vs)
	s_shader_cache_vertex vertex;	
	blend_cache_geometry_by_indices(indices, vertex, position);
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;

	prt_ravi_diff= vertex.light_param;

	// world space direction to eye/camera
	fragment_to_camera_world_wetness.xyz= Camera_Position-vertex.position;	
	fragment_to_camera_world_wetness.a= 0;

#ifdef SCOPE_TRANSPARENTS	
	inscatter_extinction= float4(0,0,0,1);
#endif
	
#endif 
} // static_prt_ambient_vs


ACCUM_PIXEL static_prt_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float4 fragment_to_camera_world_wetness : TEXCOORD6,
	in float4 prt_ravi_diff : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction: COLOR0
#endif
	)
{
	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif
//	float3 view_dir= normalize(fragment_to_camera_world_wetness.xyz);			// world space direction to eye/camera
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};



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
	
	convert_uber_light_to_analytical_light(analytical_lighting_direction,  analytical_lighting_intensity, fragment_to_camera_world_wetness.xyz);
	
	float3 bump_normal;
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		lighting_coefficients,
		fragment_to_camera_world_wetness.xyz,
		texcoord,
		prt_ravi_diff,
		analytical_lighting_direction,
		analytical_lighting_intensity,
		interpolated_inscatter_extinction.a,
		interpolated_inscatter_extinction.rgb,
		fragment_to_camera_world_wetness.a,
		bump_normal);
				
#ifdef SINGLE_PASS_LIGHTING_ENTRY_POINT
	return convert_to_render_target(out_color, bump_normal, 1.0f, false, false);
#else
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, false, false);	
#endif // SINGLE_PASS_LIGHTING
}


//
// single_pass_single_probe_ambient
//
#ifndef pc	

void single_pass_single_probe_ambient_vs(
#if defined(_standard_vs)
	in vertex_type vertex,	
	in float vertex_index : INDEX,		// use vertex_index to fetch wetness info		
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float4 fragment_to_camera_world_wetness : TEXCOORD6,
	out float4 prt_ravi_diff : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	out float4 inscatter_extinction	: COLOR0
#endif
	)
#endif
{
#if defined(_standard_vs)
	static_prt_ambient_vs(
		vertex, vertex_index, 
		position, texcoord, 
		normal, binormal, tangent, fragment_to_camera_world_wetness, prt_ravi_diff
#ifdef SCOPE_TRANSPARENTS
		, inscatter_extinction
#endif
		);		

#elif defined(_xenon_tessellation_pre_pass_vs)
	static_prt_ambient_vs(vertex_index);		

#elif defined(_xenon_tessellation_post_pass_vs)
	static_prt_ambient_vs(
		indices, 
		position, texcoord, 
		normal, binormal, tangent, fragment_to_camera_world_wetness, prt_ravi_diff
#ifdef SCOPE_TRANSPARENTS
		, inscatter_extinction
#endif
	);				
#endif 
} // single_pass_single_probe_vs


ACCUM_PIXEL single_pass_single_probe_ambient_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float4 fragment_to_camera_world_wetness : TEXCOORD6,
	in float4 prt_ravi_diff : TEXCOORD7
#ifdef SCOPE_TRANSPARENTS
	,
	in float4 interpolated_inscatter_extinction : COLOR0
#endif
	)
{
	return static_prt_ps(
		fragment_position, texcoord,
		normal, binormal, tangent,
		fragment_to_camera_world_wetness, 
		prt_ravi_diff
#ifdef SCOPE_TRANSPARENTS
		,interpolated_inscatter_extinction
#endif
		);
}
#endif // !pc


#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void default_dynamic_light_vs(
#if defined(_standard_vs)
	in vertex_type vertex,
#elif defined(_xenon_tessellation_post_pass_vs)
	in s_vertex_type_trilist_index indices,	
#endif

#if defined(_xenon_tessellation_pre_pass_vs)
	in int vertex_index : INDEX)
#else
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4,
	out float4 fragment_position_shadow : TEXCOORD5)		// homogenous coordinates of the fragment position in projective shadow space
#endif
{
#if defined(_standard_vs)
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
	fragment_position_shadow= mul(float4(vertex.position.xyz, 1.f), Shadow_Projection);

#elif defined(_xenon_tessellation_pre_pass_vs)
	vertex_type vertex;
	float4 local_to_world_transform[3];	
	deform(vertex_index, vertex, local_to_world_transform);	

	// output
	memory_export_geometry_to_stream(vertex_index, vertex, 0);
	memory_export_flush();

#elif defined(_xenon_tessellation_post_pass_vs)
	s_shader_cache_vertex vertex;	
	blend_cache_geometry_by_indices(indices, vertex, position);

	// normal, tangent and binormal are all in world space
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
	fragment_position_shadow= mul(float4(vertex.position.xyz, 1.f), Shadow_Projection);

#endif 
} // default_dynamic_light_vs


accum_pixel default_dynamic_light_ps(
	in float2 fragment_position : VPOS,
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
	in float4 fragment_position_shadow : TEXCOORD5,			// homogenous coordinates of the fragment position in projective shadow space
	bool cinematic)					
{
	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif

	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// convert view direction to tangent space
	float3 view_dir= normalize(fragment_to_camera_world);
	float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);
	
	// run pre-shader operations (used for material blending modes)
	PRE_SHADER(original_texcoord);
	
	// compute parallax
	float2 texcoord;
	{
		calc_parallax_ps(original_texcoord, view_dir_in_tangent_space, texcoord);

		// do alpha test
		calc_alpha_test_ps(texcoord);
	}

	// calculate simple light falloff for expensive light
	float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
	float3 light_radiance;
	float3 fragment_to_light;
	float light_dist2;
	calculate_simple_light(
		0,
		fragment_position_world,
		light_radiance,
		fragment_to_light);			// return normalized direction to the light

	fragment_position_shadow.xyz /= fragment_position_shadow.w;							// projective transform on xy coordinates
	
	// apply light gel
	light_radiance *=  tex2D(dynamic_light_gel_texture, transform_texcoord(fragment_position_shadow.xy, p_dynamic_light_gel_xform));
	
	// clip if the pixel is too far
//	clip(light_radiance - 0.0000001f);				// ###ctchou $TODO $REVIEW turn this into a dynamic branch?

	// get diffuse albedo, specular mask and bump normal
	float3 bump_normal;
	float4 albedo;	
	get_albedo_and_normal(bump_normal, albedo, texcoord, tangent_frame, fragment_to_camera_world, fragment_position);
	restore_specular_mask(albedo, analytical_specular_contribution);


	// calculate view reflection direction (in world space of course)
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	///    and hlsl reflect can do that directly
	///float3 view_reflect_dir= normalize( (dot(view_dir, bump_normal) * bump_normal - view_dir) * 2 + view_dir );
	float3 view_reflect_dir= -normalize(reflect(view_dir, bump_normal));

	// calculate diffuse lobe
	float3 analytic_diffuse_radiance= light_radiance * saturate(dot(fragment_to_light, bump_normal) + diffuse_light_cosine_raise) * albedo.rgb / pi;
	float3 radiance= analytic_diffuse_radiance * GET_MATERIAL_DIFFUSE_MULTIPLIER(material_type)();
	
	float raised_analytical_light_equation_a= (raised_analytical_light_maximum-raised_analytical_light_minimum)/2;
	float raised_analytical_light_equation_b= (raised_analytical_light_maximum+raised_analytical_light_minimum)/2;
	float raised_analytical_dot_product= dot(fragment_to_light, bump_normal)*raised_analytical_light_equation_a+raised_analytical_light_equation_b;
	

	// calculate specular lobe
	float specular_mask;
	calc_specular_mask_ps(texcoord, albedo.w, specular_mask);
	
	float4 spatially_varying_material_parameters= 0;	
	{
		float3 specular_albedo_color;
		float power_or_roughness;
		float3 analytic_specular_radiance;
		float3 additional_diffuse_radiance= 0;

		CALC_MATERIAL_ANALYTIC_SPECULAR(material_type)(
			view_dir,
			bump_normal,
			view_reflect_dir,
			fragment_to_light,
			light_radiance,
			albedo,									// diffuse reflectance (ignored for cook-torrance)
			texcoord,
			1.0f,
			tangent_frame,
			spatially_varying_material_parameters,			// only when use_material_texture is defined
			specular_albedo_color,							// specular reflectance at normal incidence
			analytic_specular_radiance,						// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
			additional_diffuse_radiance);					// additional non-specular radiance for some special material like organism
	
		// the point_Lighting_roughness may be tweaked inside material implementation
		float3 specular_multiplier= GET_MATERIAL_ANALYTICAL_SPECULAR_MULTIPLIER(material_type)(specular_mask);

		radiance += 
			analytic_specular_radiance*specular_multiplier +
			additional_diffuse_radiance * GET_MATERIAL_DIFFUSE_MULTIPLIER(material_type)();
	}
	
	// calculate shadow
	float unshadowed_percentage= 1.0f;
	if (dynamic_light_shadowing)
	{
		{
			float cosine= dot(normal.xyz, p_vmf_lighting_constant_1.xyz);								// p_vmf_lighting_constant_1.xyz = normalized forward direction of light (along which depth values are measured)
	//		float cosine= dot(normal.xyz, Shadow_Projection_z.xyz);

			float slope= sqrt(1-cosine*cosine) / cosine;										// slope == tan(theta) == sin(theta)/cos(theta) == sqrt(1-cos^2(theta))/cos(theta)
	//		slope= min(slope, 4.0f) + 0.2f;														// don't let slope get too big (results in shadow errors - see master chief helmet), add a little bit of slope to account for curvature
																								// ###ctchou $REVIEW could make this (4.0) a shader parameter if you have trouble with the masterchief's helmet not shadowing properly	

	//		slope= slope / dot(p_vmf_lighting_constant_1.xyz, fragment_to_light.xyz);				// adjust slope to be slope for z-depth
																			
			float half_pixel_size= p_vmf_lighting_constant_1.w * fragment_position_shadow.w;		// the texture coordinate distance from the center of a pixel to the corner of the pixel - increases linearly with increasing depth
			float depth_bias= (slope + 0.2f) * half_pixel_size;

			depth_bias= 0.0f;
		
			if (cinematic)
			{
				unshadowed_percentage= sample_percentage_closer_PCF_5x5_block_predicated(fragment_position_shadow, depth_bias);
			}
			else
			{
				unshadowed_percentage= sample_percentage_closer_PCF_3x3_block(fragment_position_shadow, depth_bias);
			}
		}
	}
	
	// prebake analytical tint
	float envmap_area_specular_only= raised_analytical_dot_product * light_radiance * unshadowed_percentage * 0.25f;
	envmap_area_specular_only= max(envmap_area_specular_only , 0.001f);
	float4 envmap_specular_reflectance_and_roughness;
	envmap_specular_reflectance_and_roughness.xyz= spatially_varying_material_parameters.b * 
         specular_mask * 
         spatially_varying_material_parameters.r;
    envmap_specular_reflectance_and_roughness.w= spatially_varying_material_parameters.a;
	
	float3 envmap_radiance= CALC_ENVMAP(envmap_type)(view_dir, bump_normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, false);
	radiance+= envmap_radiance;

	float4 out_color;
	
	// set color channels
	out_color.xyz= (radiance) * g_exposure.rrr * unshadowed_percentage;

	float output_alpha= 1.0f;
	
	// set alpha channel
	out_color.w= ALPHA_CHANNEL_OUTPUT;

	return convert_to_render_target(out_color, true, true);
}


accum_pixel dynamic_light_ps(
	in float2 fragment_position : VPOS,
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
	in float4 fragment_position_shadow : TEXCOORD5)			// homogenous coordinates of the fragment position in projective shadow space
{
	return default_dynamic_light_ps(fragment_position, original_texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, false);
}

accum_pixel dynamic_light_cine_ps(
	in float2 fragment_position : VPOS,
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
	in float4 fragment_position_shadow : TEXCOORD5)			// homogenous coordinates of the fragment position in projective shadow space
{
	return default_dynamic_light_ps(fragment_position, original_texcoord, normal, binormal, tangent, fragment_to_camera_world, fragment_position_shadow, true);
}

//===============================================================
// DEBUG

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void lightmap_debug_mode_vs(
	in vertex_type vertex,
	in s_lightmap_per_pixel lightmap,
	out float4 position : POSITION,
	out float2 lightmap_texcoord:TEXCOORD0,
	out float3 normal:TEXCOORD1,
	out float2 texcoord:TEXCOORD2,
	out float3 tangent:TEXCOORD3,
	out float3 binormal:TEXCOORD4,
	out float3 fragment_to_camera_world:TEXCOORD5)
{

	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	lightmap_texcoord= lightmap.texcoord;	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;
	fragment_to_camera_world= Camera_Position-vertex.position.xyz;
}

accum_pixel lightmap_debug_mode_ps(
	in float2 lightmap_texcoord:TEXCOORD0,
	in float3 normal:TEXCOORD1,
	in float2 texcoord:TEXCOORD2,
	in float3 tangent:TEXCOORD3,
	in float3 binormal:TEXCOORD4,
	in float3 fragment_to_camera_world:TEXCOORD5) : COLOR
{   	
	float4 out_color;
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};
	float3 bump_normal;
	
	calc_bumpmap_ps(texcoord, fragment_to_camera_world, tangent_frame, bump_normal);

	float3 ambient_only= 0.0f;
	float3 linear_only= 0.0f;
	float3 quadratic= 0.0f;

	out_color= display_debug_modes(
		lightmap_texcoord,
		normal,
		texcoord,
		tangent,
		binormal,
		bump_normal,
		ambient_only,
		linear_only,
		quadratic);
		
	return convert_to_render_target(out_color, true, false);
	
}

