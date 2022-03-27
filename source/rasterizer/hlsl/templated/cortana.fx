
// hardcoded options
#define calc_bumpmap_ps calc_bumpmap_default_ps
#define material_type cook_torrance
#define calc_self_illumination_ps calc_self_illumination_none_ps
#define calc_specular_mask_ps calc_specular_mask_from_diffuse_ps

//#define DISABLE_DYNAMIC_LIGHTS

#include "templated\templated_globals.fx"

#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"

#include "templated\albedo.fx"
#include "templated\parallax.fx"
#include "templated\bump_mapping.fx"
#include "templated\self_illumination.fx"
#include "templated\specular_mask.fx"
#include "templated\materials\material_models.fx"
#include "templated\environment_mapping.fx"
#include "shared\atmosphere.fx"
#include "templated\alpha_test.fx"

float3 bloom_override;
//#define BLOOM_OVERRIDE bloom_override

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"


#undef CONVERT_TO_RENDER_TARGET_FOR_BLEND
#define CONVERT_TO_RENDER_TARGET_FOR_BLEND convert_to_render_target
#define BLEND_FOG_INSCATTER_SCALE 1.0
#define NO_ALPHA_TO_COVERAGE


#define ALPHA_OPTIMIZATION

#ifndef APPLY_OVERLAYS
#define APPLY_OVERLAYS(color, texcoord, view_dot_normal)
#endif // APPLY_OVERLAYS



int layer_count;
float layer_depth;
float layer_contrast;
float texcoord_aspect_ratio;			// how stretched your texcoords are
float depth_darken;
float4 detail_color;

float4 calc_detail_multilayer_ps(
	in float2 texcoord,
	in float3 view_dir)
{
	texcoord= transform_texcoord(texcoord, detail_map_xform);				// transform texcoord first
	float2 offset= view_dir.xy * detail_map_xform.xy * float2(texcoord_aspect_ratio, 1.0f) * layer_depth / layer_count;
	
	float4 accum= float4(0.0f, 0.0f, 0.0f, 0.0f);
	float depth_intensity= 1.0f;
	for (int x= 0; x < layer_count; x++)
	{
		accum += depth_intensity * tex2D(detail_map, texcoord);
		texcoord -= offset;	depth_intensity *= depth_darken;
	}
	accum.rgba /= layer_count;
	
	float4 result;
	result.rgb= pow(accum.rgb, layer_contrast) * detail_color.rgb;
	result.a= accum.a * detail_color.a;
	return result;
}


sampler scanline_map;
float4 scanline_map_xform;
float scanline_amount_opaque;
float scanline_amount_transparent;


void calc_albedo_cortana_ps(
	in float2 texcoord,
	in float3 normal,
	in float3 view_dir,
	in float2 fragment_position,
	out float4 albedo)
{
	float4	base=		tex2D(base_map,		transform_texcoord(texcoord, base_map_xform)) * albedo_color;
	
	// sample scanlines
	float4 scanline= tex2D(scanline_map, transform_texcoord(fragment_position.xy, scanline_map_xform));
	float scanline_amount= lerp(scanline_amount_transparent, scanline_amount_opaque, base.w);
	scanline= lerp(float4(1.0f, 1.0f, 1.0f, 1.0f), scanline, scanline_amount);
	base.rgb *= scanline.rgb;		// * base.w

	// sampled detail	
	float4	detail=		calc_detail_multilayer_ps(texcoord, view_dir);			//  tex2D(detail_map,	transform_texcoord(texcoord, detail_map_xform));

	albedo.xyz= base.xyz + (1.0f - base.w) * detail.xyz;
	albedo.w= base.w * scanline.a + (1.0f - base.w) * detail.w;
}


float4 calc_output_color_with_explicit_light_quadratic(
	float2 fragment_position,
	float3x3 tangent_frame,				// = {tangent, binormal, normal};
	float4 sh_lighting_coefficients[4],
	float3 fragment_to_camera_world,	// direction to eye/camera, in world space
	float2 texcoord,
	float4 prt_ravi_diff,
	float3 light_direction,
	float3 light_intensity,
	float3 extinction,
	float4 inscatter)
{
	float3 view_dir= normalize(fragment_to_camera_world);

	// convert view direction to tangent space
	float3 view_dir_in_tangent_space= mul(tangent_frame, view_dir);
	
	// do alpha test
	calc_alpha_test_ps(texcoord);

	// get diffuse albedo, specular mask and bump normal
	float3 bump_normal;
	float4 albedo;	
	{
		calc_bumpmap_ps(texcoord, fragment_to_camera_world, tangent_frame, bump_normal);
		calc_albedo_cortana_ps(texcoord, bump_normal, view_dir_in_tangent_space, fragment_position, albedo);
	}

	// normalize bump to make sure specular is smooth as a baby's bottom	
	float normal_lengthsq= dot(bump_normal.xyz, bump_normal.xyz);
	bump_normal /= sqrt(normal_lengthsq);

	float specular_mask;
	calc_specular_mask_ps(texcoord, albedo.w, specular_mask);

	// calculate view reflection direction (in world space of course)
	float view_dot_normal=	dot(view_dir, bump_normal);
	///  DESC: 18 7 2007   13:57 BUNGIE\yaohhu :
	///    do not need normalize
	float3 view_reflect_dir= (view_dot_normal * bump_normal - view_dir) * 2 + view_dir;

	float4 envmap_specular_reflectance_and_roughness;
	float3 envmap_area_specular_only;
	float4 specular_radiance;
	float3 diffuse_radiance= ravi_order_3(bump_normal, sh_lighting_coefficients);
	float4 lightint_coefficients[4]= 
	{
		sh_lighting_coefficients[0], 
		sh_lighting_coefficients[1], 
		sh_lighting_coefficients[2], 
		sh_lighting_coefficients[3], 
	};
	
	calc_material_cook_torrance_ps(
		view_dir,						// normalized
		fragment_to_camera_world,		// actual vector, not normalized
		bump_normal,					// normalized
		view_reflect_dir,				// normalized
		
		lightint_coefficients,	
		light_direction,				// normalized
		light_intensity,
		
		albedo.xyz,					// diffuse_reflectance
		specular_mask,
		texcoord,
		prt_ravi_diff,

		tangent_frame,

		envmap_specular_reflectance_and_roughness,
		envmap_area_specular_only,
		specular_radiance,
		diffuse_radiance);
		
	//compute environment map
	envmap_area_specular_only= max(envmap_area_specular_only, 0.001f);
	float3 envmap_radiance= CALC_ENVMAP(envmap_type)(view_dir, bump_normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, false);

	//compute self illumination	
	float3 self_illum_radiance= calc_self_illumination_ps(texcoord, albedo.xyz, view_dir_in_tangent_space, fragment_position, fragment_to_camera_world, view_dot_normal);	// * ILLUM_SCALE;
	
	// set color channels
	float4 out_color;
	out_color.xyz= (diffuse_radiance * albedo.xyz + specular_radiance + self_illum_radiance + envmap_radiance);
	APPLY_OVERLAYS(out_color.xyz, texcoord, view_dot_normal)
	out_color.xyz= (out_color.xyz * extinction.x + inscatter * BLEND_FOG_INSCATTER_SCALE) * g_alt_exposure.ggg * 2.0f;
	out_color.w= 1.0f - albedo.w;

	return out_color;
}


sampler fade_noise_map;
float4 fade_noise_map_xform;
float noise_amount;
float fade_offset;
float warp_fade_offset;

void static_prt_ambient_vs(
	in vertex_type vertex,
#ifdef pc
#else // xenon
	in float vertex_index : INDEX,
#endif // xenon
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4,
	out float4 prt_ravi_diff : TEXCOORD5,
	out float3 extinction : COLOR0,
	out float4 inscatter : COLOR1,
	out float4 perturb : TEXCOORD6)
{
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

	perturb.x= dot(vertex.normal, -Camera_Right);
 	perturb.y= dot(vertex.normal, Camera_Up);
   	
   	// Spherical texture projection 
   	perturb.z= atan2((vertex.position.x - 0.5f) * Position_Compression_Scale.x, (vertex.position.y - 0.5f) * Position_Compression_Scale.y);
   	float aspect= Position_Compression_Scale.z / length(Position_Compression_Scale.xy);
   	perturb.w= acos(vertex.position.z - 0.5f) * aspect;

 	//output to pixel shader
	float4 local_to_world_transform[3];
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	// world space direction to eye/camera
	fragment_to_camera_world= Camera_Position-vertex.position;
	
	float ambient_occlusion= prt_c0;
	float lighting_c0= 	dot(v_lighting_constant_0.xyz, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));			// ###ctchou $PERF convert to monochrome before passing in!
	float ravi_mono= (0.886227f * lighting_c0)/3.1415926535f;
	float prt_mono= ambient_occlusion * lighting_c0;
		
	prt_mono= max(prt_mono, 0.01f);													// clamp prt term to be positive
	ravi_mono= max(ravi_mono, 0.01f);									// clamp ravi term to be larger than prt term by a little bit
	float prt_ravi_ratio= prt_mono /ravi_mono;
	prt_ravi_diff.x= prt_ravi_ratio;												// diffuse occlusion % (prt ravi ratio)
	prt_ravi_diff.y= prt_mono;														// unused
	prt_ravi_diff.z= (ambient_occlusion * 3.1415926535f)/0.886227f;					// specular occlusion % (ambient occlusion)
	prt_ravi_diff.w= min(dot(normal, v_analytical_light_direction), prt_mono);		// specular (vertex N) dot L (kills backfacing specular)
		
	compute_scattering(Camera_Position, vertex.position, inscatter.xyz, extinction.x);
	extinction.yz= 0.0f;
	
	float4 vertex_transparency= 1.0f;
	float2 vt_texcoord= transform_texcoord(position.xy, fade_noise_map_xform);
#ifndef pc
	asm {
		tfetch2D vertex_transparency, vt_texcoord, fade_noise_map, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, UseComputedLOD= false
	};
#endif // !pc
	inscatter.w= fade_offset + (vertex_transparency.r * (2 * noise_amount) - noise_amount);
}


accum_pixel static_prt_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
	in float4 prt_ravi_diff : TEXCOORD5,
	in float3 extinction : COLOR0,
	in float4 inscatter : COLOR1,
	in float4 perturb : TEXCOORD6)
{
	// normalize interpolated values
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);

//	float3 view_dir= normalize(fragment_to_camera_world);			// world space direction to eye/camera
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// build sh_lighting_coefficients
	float4 sh_lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0, 
			p_vmf_lighting_constant_1, 
			p_vmf_lighting_constant_2, 
			p_vmf_lighting_constant_3, 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0) 
		}; 
	
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		sh_lighting_coefficients,
		fragment_to_camera_world,
		texcoord,
		prt_ravi_diff,
		k_ps_analytical_light_direction,
		k_ps_analytical_light_intensity,
		extinction,
		inscatter);
				
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}


///constant to do order 2 SH convolution
void static_sh_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float3 texcoord_and_vertexNdotL : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float3 fragment_to_camera_world : TEXCOORD6,
	out float3 extinction : COLOR0,
	out float3 inscatter : COLOR1)
{

	//output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binromal);
	
	normal= vertex.normal;
	texcoord_and_vertexNdotL.xy= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;
	
	texcoord_and_vertexNdotL.z= dot(normal, v_analytical_light_direction);
		
	// world space direction to eye/camera
	fragment_to_camera_world.rgb= Camera_Position-vertex.position;
	
	compute_scattering(Camera_Position, vertex.position, inscatter, extinction.x);
	extinction.yz= 0.0f;
}


accum_pixel static_sh_ps(
	in float2 fragment_position : VPOS,
	in float3 texcoord_and_vertexNdotL : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float3 fragment_to_camera_world : TEXCOORD6,
	in float3 extinction : COLOR0,
	in float4 inscatter : COLOR1)
{
	// normalize interpolated values
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// build sh_lighting_coefficients
	float4 sh_lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0, 
			p_vmf_lighting_constant_1, 
			p_vmf_lighting_constant_2, 
			p_vmf_lighting_constant_3, 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0) 
		}; 	
	
	float4 prt_ravi_diff= float4(1.0f, 0.0f, 1.0f, dot(tangent_frame[2], k_ps_analytical_light_direction));
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		sh_lighting_coefficients,
		fragment_to_camera_world,
		texcoord_and_vertexNdotL.xy,
		prt_ravi_diff,
		k_ps_analytical_light_direction,
		k_ps_analytical_light_intensity,
		extinction,
		inscatter);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}


void active_camo_vs(
	in vertex_type vertex,
#ifdef pc
#else // xenon
	in float vertex_index : INDEX,
#endif // xenon
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4,
	out float4 prt_ravi_diff : TEXCOORD5,
	out float3 extinction : COLOR0,
	out float4 inscatter : COLOR1,
	out float4 perturb : TEXCOORD6)
{
	static_prt_ambient_vs(
		vertex,
#ifdef pc
#else // xenon		
		vertex_index,
#endif // xenon
		position,
		texcoord.xy,
		normal,
		binormal,
		tangent,
		fragment_to_camera_world,
		prt_ravi_diff,
		extinction,
		inscatter,
		perturb);   	
		
	texcoord.z= 0.0f;
   	texcoord.w= length(vertex.position - Camera_Position);	
}


sampler active_camo_distortion_texture;
float warp_amount;

sampler fade_gradient_map;
float4 fade_gradient_map_xform;
float fade_gradient_scale;

accum_pixel active_camo_ps(
	in float2 fragment_position : VPOS,
	in float4 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
	in float4 prt_ravi_diff : TEXCOORD5,
	in float3 extinction : COLOR0,
	in float4 inscatter : COLOR1,
	in float4 perturb : TEXCOORD6)
{
	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	normal= normalize(normal);
	binormal= normalize(binormal);
	tangent= normalize(tangent);
#endif
//	float3 view_dir= normalize(fragment_to_camera_world);			// world space direction to eye/camera
	
	// setup tangent frame
	float3x3 tangent_frame = {tangent, binormal, normal};

	// build sh_lighting_coefficients
	float4 sh_lighting_coefficients[4]=
		{
			p_vmf_lighting_constant_0, 
			p_vmf_lighting_constant_1, 
			p_vmf_lighting_constant_2, 
			p_vmf_lighting_constant_3, 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0), 
			float4(0,0,0,0) 
		}; 
	
	float4 color_transparency= calc_output_color_with_explicit_light_quadratic(
		fragment_position,
		tangent_frame,
		sh_lighting_coefficients,
		fragment_to_camera_world,
		texcoord.xy,
		prt_ravi_diff,
		k_ps_analytical_light_direction,
		k_ps_analytical_light_intensity,
		extinction,
		inscatter);

	// grab screen position
	float2 uv= float2((fragment_position.x + 0.5f) / texture_size.x, (fragment_position.y + 0.5f) / texture_size.y);
	
	float transparency= tex2D(fade_gradient_map, transform_texcoord(texcoord.xy, fade_gradient_map_xform)).a * fade_gradient_scale + inscatter.w;
	
	float2 uvdelta= perturb.xy * warp_amount * saturate(transparency + warp_fade_offset)  * float2(1.0f/16.0f, 1.0f/9.0f);
	//uvdelta+= tex2D(active_camo_distortion_texture, perturb.zw * float2(4.0f, 4.0f)).xy * float2(0.1f, 0.1f);
	
	// Perspective correction so we don't distort too much in the distance
	// (and clamp the amount we distort in the foreground too)
	uv.xy+= uvdelta / max(0.5f, texcoord.w);
	
	// HDR texture is currently not used
	//float4 hdr_color= tex2D(scene_hdr_texture, uv.xy);	
	float4 ldr_color= tex2D(scene_ldr_texture, uv.xy);
	
	float3 true_scene_color= lerp(color_transparency.rgb, ldr_color.rgb, saturate(color_transparency.a + saturate(1.0f-transparency)));
	float4 result= float4(true_scene_color, 1.0f);
	
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(result, false, false);
}


void albedo_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4)
{
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binromal);
	
	// normal, tangent and binormal are all in world space
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
}


albedo_pixel albedo_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4)
{
	// do alpha test
	calc_alpha_test_ps(texcoord);

	float4	base=		tex2D(base_map,		transform_texcoord(texcoord, base_map_xform)) * albedo_color;

	float approximate_specular_type= 0.0f;
	return convert_to_albedo_target(base, normal, approximate_specular_type);
}
