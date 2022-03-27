
#define	BLEND_MODE_OFF	// no alpha blending for foliage
#include "templated\templated_globals.fx"

#include "templated\analytical_mask.fx"

#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"

#include "templated\albedo.fx"
#include "shared\atmosphere.fx"
#include "templated\alpha_test.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"


#include "templated\velocity.fx"

#define SAMPLE_ALBEDO_FOR_SHADOW_GENERATE
#include "shadows\shadow_generate.fx"

#include "shared\spherical_harmonics.fx"

#include "templated\lightmap_sampling.fx"

#include "templated\wetness.fx"


#define MATERIAL_TYPE(material) MATERIAL_TYPE_##material
#define MATERIAL_TYPE_translucent 0
#define MATERIAL_TYPE_specular 1
#define MATERIAL_TYPE_flat 2

#if defined(entry_point_imposter_static_sh)
	#define static_sh_vs imposter_static_sh_vs
	#define static_sh_ps imposter_static_sh_ps
	#define SHADER_FOR_IMPOSTER
#elif defined(entry_point_imposter_static_prt_ambient)
	#define static_prt_ambient_vs imposter_static_prt_ambient_vs
	#define static_prt_ps imposter_static_prt_ps
	#define SHADER_FOR_IMPOSTER
#endif

extern float g_tree_animation_coeff;

float animation_amplitude_horizontal;

float foliage_translucency;  // it should be a teture in the future.

float3 foliage_specular_color;
float foliage_specular_intensity;
float foliage_specular_power;

sampler2D unused_sampler;

// TODO: move this to a shared file. it is shared with explicit\render_instance_imposter.hlsl
float3 calc_normal_from_position(
	in float3 fragment_position_world)
{
//#ifndef pc
#if 0
	float4 gradient_horz, gradient_vert;
	
	// gradient_vert=	dx/dv, dy/dv, dx/dh, dy/dh
	// gradient_horz=	dz/dh, dz/dv, dz/dh, dz/dv
	asm {
		getGradients gradient_vert.ywxz, fragment_position_world.xy, unused_sampler
		getGradients gradient_horz.xyzw, fragment_position_world.zz, unused_sampler
	};

	gradient_horz.xy=	gradient_vert.zw;		// gradient_horz=	dx/dh, dy/dh, dz/dh, dz/dv
	gradient_vert.z=	gradient_horz.w;		// gradient_vert=	dx/dv, dy/dv, dz/dv, dy/dh

	float3 bump_normal=	normalize( -cross(gradient_horz.xyz, gradient_vert.xyz) );
	return bump_normal;
#else // PC
	float3 dBPx= ddx(fragment_position_world);		// worldspace gradient along pixel x direction
	float3 dBPy= ddy(fragment_position_world);		// worldspace gradient along pixel y direction
	float3 bump_normal= -normalize( cross(dBPx, dBPy) );	
	return bump_normal;
#endif // PC
}

// 
// DESC: 
// params
//   Desc: phase offset
// Return 
//   Desc a vaule -1 to 1
// @pre
// @post
// @invariants

float vibration(in float offset)
{
	///  DESC: 1 7 2007   21:35 BUNGIE\yaohhu :
	///    Use frc and abs make a repeat forth back movement
	float vibration_base= abs(frac(offset+g_tree_animation_coeff)-0.5f)*2;
	// Use taylor to simulate spring
	float x=(0.5f-vibration_base)*3.14159265f;
	return sin(x);
}

// 
// DESC: Displace leaf branch's vertex position in 3d space (world space usually)
// params
//   Desc: 
// Return 
//   Desc 
// @pre  texture_coord should be placed randomly
// @post
// @invariants

float3 animation_offset(in float2 texture_coord)
{    
    //if(texture_coord.y<0)		return float3(0,0,15);
    float distance=frac(texture_coord.x);
    
	float id=texture_coord.x-distance+3; //add a minimum offset
	float vibration_coeff_horizontal= vibration(id/0.53);
	id+=floor(texture_coord.y)*7;
	float vibration_coeff_vertical= vibration(id/1.1173);
	float dirx= frac(id/0.727)-0.5f;
	float diry= frac(id/0.371)-0.5f;
	
	return float3(
		float2(dirx,diry)*vibration_coeff_horizontal,
		vibration_coeff_vertical*0.3f)*
		distance*animation_amplitude_horizontal;
}

#define DEFORM_TYPE(deform) DEFORM_TYPE_##deform
#define DEFORM_TYPE_deform_world 0
#define DEFORM_TYPE_deform_rigid 1

///  $FIXME: 2 7 2007   12:12 BUNGIE\yaohhu :
///    I copied the above function and added my code without understanding it
///    a modified version of always_local_to_view(...)
void tree_animation_special_local_to_view(
    inout vertex_type vertex,
    out float4 local_to_world_transform[3], 
    out float4 position)
{
    // always practice safe-shader-compilation, kids.
    // (brought to you by trojan)
    [isolate]
    {
       if (always_true)
       {
         vertex_type vertex_copy= vertex;
         float4 local_to_world_transform_copy[3];
         deform(vertex_copy, local_to_world_transform_copy);
         
         ///  $FIXME: 3 7 2007   10:32 BUNGIE\yaohhu :
         ///    some time deform = deform_rigid  which need decompression
         ///    some time deform = deform_world  which don't need decompression
         ///    Can we fix foliage's usage?
#if DEFORM_TYPE(deform) == DEFORM_TYPE_deform_world
		 float2 vertex_texture_coord=vertex.texcoord;
#elif DEFORM_TYPE(deform) == DEFORM_TYPE_deform_rigid
         float2 vertex_texture_coord=vertex.texcoord*UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
#else
         float2 vertex_texture_coord=float2(0,0);
         // and probabally crash me here next time.
#endif
         vertex_copy.position.xyz+=animation_offset(vertex_texture_coord);
         position= mul(float4(vertex_copy.position.xyz, 1.0f), View_Projection);	//###natashat $TODO - ensure that this gets written out to oPosition..
       }
       else 
       {
         position= float4(0, 0, 0, 0);
       }
    }
    
    deform(vertex, local_to_world_transform);
}


//entry point albedo
void albedo_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal:	TEXCOORD1)
{
	float4 local_to_world_transform[3];
		
	//output to pixel shader
	tree_animation_special_local_to_view(vertex, local_to_world_transform, position);

	normal= vertex.normal;
	texcoord= vertex.texcoord;
}

albedo_pixel albedo_ps(
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1)
{		
	float4 albedo;
	calc_albedo_ps(original_texcoord, albedo, normal);
	
	calc_alpha_test_ps(original_texcoord, albedo);
	
#ifndef NO_ALPHA_TO_COVERAGE
//	albedo.w= output_alpha;
#endif
	
	float approximate_specular_type= 1.0f;
	return convert_to_albedo_target(albedo, normal, approximate_specular_type);
}

float diffuse_coefficient;
float specular_coefficient;
float back_light;
float roughness;


void static_sh_common_vs_for_flat_material_option_base(
	in	vertex_type vertex,
	out float4 		position,
	out float4 		texcoord,
	out float4 		front_face_lighting,
	out float4		back_face_lighting)
{	
	// output to pixel shader
	float4 local_to_world_transform[3];
	tree_animation_special_local_to_view(vertex, local_to_world_transform, position);
	
	texcoord= float4(vertex.texcoord, get_analytical_mask_projected_texture_coordinate(vertex.position));
	
	// build sh_lighting_coefficients
	// build sh_lighting_coefficients
	float4 vmf_coefficients[4]=
	{
		v_lighting_constant_0, 
		v_lighting_constant_1, 
		v_lighting_constant_2, 
		v_lighting_constant_3, 
	}; 			
		
	front_face_lighting.xyz = dual_vmf_diffuse( vertex.normal, vmf_coefficients);
	back_face_lighting.xyz  = dual_vmf_diffuse(-vertex.normal, vmf_coefficients);
	
	float analytical_mask= v_lighting_constant_0.w;
	
	front_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction,  vertex.normal));
	back_face_lighting.w  = analytical_mask * saturate(dot(v_analytical_light_direction, -vertex.normal));
}

void static_sh_common_vs_for_flat_material_option(
	in	vertex_type vertex,
	out float4 		position,
	out float4 		texcoord,
	out float4 		omnidirectional_lighting)
{	
	float4 front_face_lighting;
	float4 back_face_lighting;

	static_sh_common_vs_for_flat_material_option_base(vertex, position, texcoord, front_face_lighting, back_face_lighting);
	omnidirectional_lighting= front_face_lighting + back_face_lighting;
}

void static_sh_common_vs(
	in int index_of_vertex,
	in vertex_type vertex,
	out float4 position,
	out float4 texcoord,
	out float4 front_face_lighting,
	out float4 back_face_lighting,
	out float wetness,
	out float4 local_to_world_transform[3],
	out float3 fragment_to_camera_world)
{	
	//output to pixel shader
	tree_animation_special_local_to_view(vertex, local_to_world_transform, position);
	
	float3 normal= vertex.normal;
	texcoord= float4(vertex.texcoord, get_analytical_mask_projected_texture_coordinate(vertex.position));
	
	// build sh_lighting_coefficients
	// build sh_lighting_coefficients
	float4 vmf_coefficients[4]=
	{
		v_lighting_constant_0, 
		v_lighting_constant_1, 
		v_lighting_constant_2, 
		v_lighting_constant_3, 
	}; 			
		
	front_face_lighting.xyz = dual_vmf_diffuse(normal, vmf_coefficients);
	back_face_lighting.xyz = dual_vmf_diffuse(-normal, vmf_coefficients);
	
	float analytical_mask= v_lighting_constant_0.w;
	
	front_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction, normal));
	back_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction, -normal));
	
	
	// calc wetness
	wetness= fetch_per_vertex_wetness_from_texture(index_of_vertex);
	
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

#ifdef pc
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

accum_pixel static_common_ps(
	in float2 fragment_position,
	in float4 texcoord,
	in float3 normal,
	in float4 front_face_lighting,
	in float4 back_face_lighting,
	in float vertex_wetness,
	in float3 fragment_to_camera_world)
{
	float4 out_color;
	float4 albedo= get_albedo(fragment_position);
	float analytical_mask;

	calc_alpha_test_ps(texcoord, albedo);
		
	float3 geometric_normal= calc_normal_from_position(fragment_to_camera_world);
	
	float3 vmf_lighting;
	float analytical_dot_product;
	float lighting_blend= ( dot(normal, geometric_normal) + 1) / 2 ;
	
	analytical_dot_product= lerp ( back_face_lighting.w, front_face_lighting.w, lighting_blend );	
	analytical_mask= get_analytical_mask_from_projected_texture_coordinate(texcoord.zw, analytical_dot_product, p_lightmap_compress_constant_0);	
	
	vmf_lighting= lerp ( back_face_lighting.rgb, front_face_lighting.rgb, lighting_blend );	

	
	float3 analytical_diffuse= analytical_mask * k_ps_analytical_light_intensity / pi ;
	out_color.xyz= (vmf_lighting + analytical_diffuse) * albedo.xyz;

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
			0, 0, 0, 
			0, vertex_wetness, 
			vmf_coeffs, 0, float4(0.0f, 0.5f, 0.5f, 1.0f), 0);
	}
#endif //NO_WETNESS_EFFECT

	out_color.rgb=  out_color.rgb * g_exposure.rrr;

	// compute velocity
	{
		out_color.w= 0; // turn on antialising ever for foliage
	}

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}


//entry_point static_sh
void static_sh_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type vertex,
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	out float3 normal : TEXCOORD3, 
	out float4 back_face_lighting : COLOR1)
{
	//output to pixel shader
	float4 local_to_world_transform[3];
	
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);
	
	normal= vertex.normal;
}

accum_pixel static_sh_ps(
	in float2 fragment_position : VPOS,
	in float4 texcoord : TEXCOORD0,
	in float4 front_face_lighting : TEXCOORD1,
	in float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float4 back_face_lighting : COLOR1)
{
	return static_common_ps(fragment_position, texcoord, normal, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
}

void static_per_pixel_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type vertex,
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_and_wetness : TEXCOORD2,	
	out float3 normal : TEXCOORD3, 
	out float4 back_face_lighting : COLOR1)
{
	float4 local_to_world_transform[3];
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);
	//no one should be using the foliage shader and per pixel lighting, output red as a warning.
	front_face_lighting.gba= back_face_lighting.gba = 0.0f;
	front_face_lighting.r= back_face_lighting.r= 1.0f;
	normal= vertex.normal;
}

accum_pixel static_per_pixel_ps(
	in float2 fragment_position : VPOS,
	in float4 texcoord : TEXCOORD0,
	in float4 front_face_lighting : TEXCOORD1,
	in float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float4 back_face_lighting: COLOR1)
{
	return static_common_ps(fragment_position, texcoord, normal, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
}

void static_per_vertex_vs(
 #ifndef pc	
	in int vertex_index : INDEX,
#endif //pc
	in vertex_type vertex,
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_wetness : TEXCOORD2,	
	out float3 normal : TEXCOORD3,
	out float4 back_face_lighting : COLOR1)
{
	// output to pixel shader
	float4 local_to_world_transform[3];
	
	//output to pixel shader
	tree_animation_special_local_to_view(vertex, local_to_world_transform, position);
	
	float4 vmf_coefficients[4];
	
    float4 vmf_light0;
    float4 vmf_light1;
    
    int vertex_index_after_offset= vertex_index - per_vertex_lighting_offset.x;
    fetch_stream(vertex_index_after_offset, vmf_light0, vmf_light1);
    
    decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf_coefficients[0], vmf_coefficients[1], vmf_coefficients[2], vmf_coefficients[3]);
    
    vmf_coefficients[2]= float4(normal,1);

	// world space vector from vertex to eye/camera
	fragment_to_camera_world_wetness.xyz= Camera_Position - vertex.position;	
	{
		float3 normal= vertex.normal;
		front_face_lighting.xyz= dual_vmf_diffuse(normal, vmf_coefficients);
		back_face_lighting.xyz= dual_vmf_diffuse(-normal, vmf_coefficients);
	}
	{		
		float3 normal= vertex.normal;
		float analytical_mask= vmf_coefficients[0].w;	
		front_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction, normal));
		back_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction, -normal));	
	}
	
	texcoord= float4(vertex.texcoord, get_analytical_mask_projected_texture_coordinate(vertex.position));
	
	// calc wetness
	fragment_to_camera_world_wetness.a= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

	normal= vertex.normal;
}

accum_pixel static_per_vertex_ps(
	in float2 fragment_position : VPOS,
	in float4 texcoord : TEXCOORD0,
	in float4 front_face_lighting : TEXCOORD1,
	in float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float4 back_face_lighting : COLOR1)
{
	return static_common_ps(fragment_position, texcoord, normal, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
}

void static_prt_ambient_vs(    
	in vertex_type vertex,
#ifndef pc
	in int vertex_index : INDEX,
#endif 
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	out float3 normal : TEXCOORD3, 
	out float4 back_face_lighting: COLOR1)
{
	float4 local_to_world_transform[3];
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);

#ifndef pc

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
	prt_c0= dot(prt_component, prt_values) * 3.545f;

    float prt_scale= prt_c0 / PRT_C0_DEFAULT;
    prt_scale= lerp(0.6,1,prt_scale);
	front_face_lighting.xyz *= prt_scale;
	

#endif // xenon

	normal= vertex.normal;

}

void static_prt_linear_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type vertex,
#ifndef pc	
	in float4 prt_c0_c3 : BLENDWEIGHT1,
#endif // !pc
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	out float3 normal:	TEXCOORD3,
	out float4 back_face_lighting : COLOR1)
{
	float4 local_to_world_transform[3];
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);
	
#ifndef pc
	front_face_lighting.xyz *= prt_c0_c3.x / PRT_C0_DEFAULT;	
#endif		

	normal= vertex.normal;
}

void static_prt_quadratic_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type vertex,
#ifndef pc	
	in float3 prt_c0_c2 : BLENDWEIGHT1,
	in float3 prt_c3_c5 : BLENDWEIGHT2,
	in float3 prt_c6_c8 : BLENDWEIGHT3,		
#endif // !pc
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0,
	out float4 front_face_lighting : TEXCOORD1,
	out float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	out float3 normal:	TEXCOORD3,
	out float4 back_face_lighting : COLOR1)
{
	float4 local_to_world_transform[3];
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);
	
#ifndef pc
	front_face_lighting *= prt_c0_c2.x / PRT_C0_DEFAULT;		
#endif

	normal= vertex.normal;
}

accum_pixel static_prt_ps(
	in float2 fragment_position : VPOS,
	in float4 texcoord : TEXCOORD0,
	in float4 front_face_lighting : TEXCOORD1,
	in float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float4 back_face_lighting : COLOR1)
{
	return static_common_ps(fragment_position, texcoord, normal, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Single pass rendering entry points
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Common pixel shader for single pass rendering for flat material model option
// Flat material type means simplified lighting. we will equally blend front & back contributions.
// There will not be specular, and we will not apply wetness in this case. 
//-----------------------------------------------------------------------------------------------------------------------------------------------------
accum_pixel_and_normal single_pass_common_ps_for_flat_material_option(
	in float4 texcoord,
	in float4 omnidirectional_lighting)
{
	float4 out_color;

	float3 const_normal= float3(1,0,1);
	
	float4 albedo;
	calc_albedo_ps(texcoord.xy, albedo, const_normal);

	float alpha_test_alpha= calc_alpha_test_ps(texcoord, albedo);

	float	analytical_contribution= omnidirectional_lighting.w;
	float3  vmf_lighting=			 omnidirectional_lighting.rgb;

	float  analytical_mask=    get_analytical_mask_from_projected_texture_coordinate(texcoord.zw, analytical_contribution, p_lightmap_compress_constant_0);			
	float3 analytical_diffuse= analytical_mask * k_ps_analytical_light_intensity / pi ;	

	out_color.rgb= (vmf_lighting + analytical_diffuse) * albedo.xyz * g_exposure.rrr;
	
	{
		out_color.w= 0; // turn on antialising ever for foliage
	}

	float approximate_specular_type= 1.0f;
	return convert_to_render_target(out_color, const_normal, approximate_specular_type, true, false);	
}


//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Common pixel shader for single pass rendering
//-----------------------------------------------------------------------------------------------------------------------------------------------------
accum_pixel_and_normal single_pass_common_ps(
	in float4 texcoord,
	in float4 front_face_lighting,
	in float3 normal,
	in float4 back_face_lighting,
	in float  vertex_wetness,
	in float3 fragment_to_camera_world)
{
	float4 out_color;

	float4 albedo;
	calc_albedo_ps(texcoord.xy, albedo, normal);	

	float alpha_test_alpha= calc_alpha_test_ps(texcoord, albedo);

	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	

		// Flat material type means simplified lighting. we will equally blend front & back contributions.
		// There will not be specular, and we will not apply wetness in this case. 

		float	analytical_contribution;
		float3  vmf_lighting;

		float4(vmf_lighting, analytical_contribution)= back_face_lighting + front_face_lighting;
		
		float analytical_mask= get_analytical_mask_from_projected_texture_coordinate(texcoord.zw, analytical_contribution, p_lightmap_compress_constant_0);			
		float3 analytical_diffuse= analytical_mask * k_ps_analytical_light_intensity / pi ;	

		out_color.xyz= (vmf_lighting + analytical_diffuse) * albedo.xyz;
			
	#else	
		// The other two material models compute slightly more complex lighting
		//
		# if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_translucent	
			float translucency= saturate(( 1 - alpha_test_alpha ) * 2 * foliage_translucency);	
			float3 specular_color= 0;
		#elif MATERIAL_TYPE(material_type) == MATERIAL_TYPE_specular	
			float translucency= foliage_translucency;
			float3 specular_color= pow( 2 * alpha_test_alpha - 1, foliage_specular_power ) * foliage_specular_color * foliage_specular_intensity;	
		#endif

		float analytical_mask;
		float3 geometric_normal= calc_normal_from_position(fragment_to_camera_world);
		{				
			float3 vmf_lighting;
			float analytical_dot_product;
			float analytical_contribution;
			
			float lighting_blend= ( dot(normal, geometric_normal) + 1) / 2;
			
			{
				analytical_dot_product= lerp ( back_face_lighting.w, front_face_lighting.w, lighting_blend );	
				
				float back_side_analytical_dot_product= lerp ( front_face_lighting.w, back_face_lighting.w, lighting_blend );	
				back_side_analytical_dot_product*= translucency;
				
				analytical_contribution= analytical_dot_product + back_side_analytical_dot_product;		
			}
		
			analytical_mask= get_analytical_mask_from_projected_texture_coordinate(texcoord.zw, analytical_contribution, p_lightmap_compress_constant_0);			
			float3 analytical_diffuse= analytical_mask * k_ps_analytical_light_intensity / pi ;
			float3 analytical_specular= analytical_mask * k_ps_analytical_light_intensity * front_face_lighting.w * specular_color * lighting_blend ;
		
			{
				vmf_lighting= lerp ( back_face_lighting.rgb, front_face_lighting.rgb, lighting_blend );	
				float3 back_side_vmf= lerp ( front_face_lighting.rgb, back_face_lighting.rgb, lighting_blend );
				
				vmf_lighting+= back_side_vmf * translucency;
			}
	
			out_color.xyz= (vmf_lighting + analytical_diffuse) * albedo.xyz + analytical_specular;
		}

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
	#endif	// Else #if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
	//*/

	out_color.rgb= out_color.rgb * g_exposure.rrr;

	// compute velocity
	{
		out_color.w= 0; // turn on antialising ever for foliage
	}

	float approximate_specular_type= 1.0f;
	return convert_to_render_target(out_color, normal, approximate_specular_type, true, false);	
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
// Single pass per pixel entry point shaders will not account for material model option because they are _NOT_ supposed to be used for foliage rendering.
//-----------------------------------------------------------------------------------------------------------------------------------------------------
void single_pass_per_pixel_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type	vertex,

	out float4		position 				 : POSITION,
	out float4		texcoord 				 : TEXCOORD0,
	out float4		front_face_lighting 	 : TEXCOORD1,
	out float4		fragment_to_camera_world_and_wetness : TEXCOORD2,	
	out float3      normal					 : TEXCOORD3,
	out float4		back_face_lighting  	 : COLOR1)
{
	float4 local_to_world_transform[3];
	static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, 
		  			    fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);
	
	//no one should be using the foliage shader and per pixel lighting, output red as a warning.
	front_face_lighting.gba= back_face_lighting.gba = 0.0f;
	front_face_lighting.r= back_face_lighting.r= 1.0f;
	
	// Propagate the normal:
	normal= vertex.normal;
}

accum_pixel_and_normal single_pass_per_pixel_ps(
	in float4 texcoord 				   : TEXCOORD0,
	in float4 front_face_lighting 	   : TEXCOORD1,
	in float4 fragment_to_camera_world_and_wetness : TEXCOORD2,
	in float3 normal				   : TEXCOORD3,
	in float4 back_face_lighting: COLOR1)
{
	return single_pass_common_ps(texcoord, front_face_lighting, normal, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
void single_pass_per_vertex_vs(
	#ifndef pc	
		in int          vertex_index : INDEX,
	#endif //pc
	in vertex_type	vertex,

	out float4 		position 				 : POSITION,
	out float4 		texcoord 				 : TEXCOORD0,
	
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		out float4	omnidirectional_lighting : TEXCOORD1
	#else
		out float4 	front_face_lighting 			 : TEXCOORD1,
		out float4	fragment_to_camera_world_wetness : TEXCOORD2,
		out float3  normal					 		 : TEXCOORD3,
		out float4	back_face_lighting       		 : COLOR1
	#endif	// MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
	)
{
	// output to pixel shader
	float4 local_to_world_transform[3];
	
	//output to pixel shader
	tree_animation_special_local_to_view(vertex, local_to_world_transform, position);
	
	float4 vmf_coefficients[4];
	
    float4 vmf_light0;
    float4 vmf_light1;
    
    int vertex_index_after_offset= vertex_index - per_vertex_lighting_offset.x;
    fetch_stream(vertex_index_after_offset, vmf_light0, vmf_light1);
    
    decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf_coefficients[0], vmf_coefficients[1], vmf_coefficients[2], vmf_coefficients[3]);
    
    vmf_coefficients[2]= float4(vertex.normal,1);
	
	texcoord= float4(vertex.texcoord,get_analytical_mask_projected_texture_coordinate(vertex.position));
	
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		float4 front_face_lighting;
		float4 back_face_lighting;
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	

	front_face_lighting.xyz= dual_vmf_diffuse( vertex.normal, vmf_coefficients);
	back_face_lighting.xyz=  dual_vmf_diffuse(-vertex.normal, vmf_coefficients);
	
	float analytical_mask= vmf_coefficients[0].w;
	
	front_face_lighting.w = analytical_mask * saturate(dot(v_analytical_light_direction,  vertex.normal));	
	back_face_lighting.w=   analytical_mask * saturate(dot(v_analytical_light_direction, -vertex.normal));
	
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		omnidirectional_lighting= front_face_lighting + back_face_lighting;
	#else
		normal= vertex.normal;

		// calc wetness
		fragment_to_camera_world_wetness.w= fetch_per_vertex_wetness_from_texture(WETNESS_VERTEX_INDEX);

		// world space vector from vertex to eye/camera
		fragment_to_camera_world_wetness.xyz= Camera_Position - vertex.position;	
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
}

accum_pixel_and_normal single_pass_per_vertex_ps(
	in float4 texcoord 				   : TEXCOORD0,
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		in float4 omnidirectional_lighting : TEXCOORD1
	#else
		in float4 front_face_lighting	   : TEXCOORD1,
		in float4 fragment_to_camera_world_wetness : TEXCOORD2,
		in float3 normal				   : TEXCOORD3,
		in float4 back_face_lighting       : COLOR1
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
	)
{
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		return single_pass_common_ps_for_flat_material_option(texcoord, omnidirectional_lighting);
	#else
		return single_pass_common_ps(texcoord, front_face_lighting, normal, back_face_lighting, fragment_to_camera_world_wetness.w, fragment_to_camera_world_wetness.xyz);	
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
// entry_point single_pass_single_probe
//-----------------------------------------------------------------------------------------------------------------------------------------------------
void single_pass_single_probe_vs(
	#ifndef pc	
	in int vertex_index : INDEX,
	#endif // !pc
	in vertex_type	vertex,

	out float4  	position 				 : POSITION,
	out float4  	texcoord 				 : TEXCOORD0,

	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		out float4	omnidirectional_lighting			: TEXCOORD1	
	#else
		out float4  front_face_lighting 				 : TEXCOORD1,
		out float4  fragment_to_camera_world_and_wetness : TEXCOORD2,	
		out float3  normal					 			 : TEXCOORD3, 
		out float4  back_face_lighting       			 : COLOR1 
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
	)
{
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		static_sh_common_vs_for_flat_material_option(vertex, position, texcoord, omnidirectional_lighting);
	#else
		//output to pixel shader
		float4 local_to_world_transform[3];
		static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world_and_wetness.w, local_to_world_transform, fragment_to_camera_world_and_wetness.xyz);

		normal= vertex.normal;
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
}

accum_pixel_and_normal single_pass_single_probe_ps(
	in float4 texcoord : TEXCOORD0,

	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		in float4 omnidirectional_lighting				: TEXCOORD1
	#else
		in float4 front_face_lighting					: TEXCOORD1,
		in float4 fragment_to_camera_world_and_wetness	: TEXCOORD2,
		in float3 normal								: TEXCOORD3,
		in float4 back_face_lighting					: COLOR1
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
	)
{
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		return single_pass_common_ps_for_flat_material_option(texcoord, omnidirectional_lighting);
	#else
		return single_pass_common_ps(texcoord, front_face_lighting, normal, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
accum_pixel_and_normal single_pass_single_probe_ambient_ps(
	in float4 texcoord				   : TEXCOORD0,

	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		in float4 omnidirectional_lighting				: TEXCOORD1
	#else
		in float4 front_face_lighting					: TEXCOORD1,
		in float4 fragment_to_camera_world_and_wetness	: TEXCOORD2,
		in float3 normal								: TEXCOORD3,
		in float4 back_face_lighting					: COLOR1
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
	)
{
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		return single_pass_common_ps_for_flat_material_option(texcoord, omnidirectional_lighting);
	#else
		return single_pass_common_ps(texcoord, front_face_lighting, normal, back_face_lighting, fragment_to_camera_world_and_wetness.w, fragment_to_camera_world_and_wetness.xyz);	
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
}

//-----------------------------------------------------------------------------------------------------------------------------------------------------
void single_pass_single_probe_ambient_vs(    
	in vertex_type	vertex,
#ifndef pc
	in int vertex_index : INDEX,
#endif 

	out float4 position 				: POSITION,
	out float4 texcoord 				: TEXCOORD0,

	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat
		out float4 omnidirectional_lighting : TEXCOORD1	
	#else
		out float4 front_face_lighting 		: TEXCOORD1,
		out float4 fragment_to_camera_world : TEXCOORD2,
		out float3 normal					: TEXCOORD3,
		out float4 back_face_lighting       : COLOR1
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat

	)
{
	#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
		float4 front_face_lighting;
		float4 back_face_lighting;
		static_sh_common_vs_for_flat_material_option_base(vertex, position, texcoord, front_face_lighting, back_face_lighting);
	#else
		float4 local_to_world_transform[3];
		static_sh_common_vs(vertex_index, vertex, position, texcoord, front_face_lighting, back_face_lighting, fragment_to_camera_world.w, local_to_world_transform, fragment_to_camera_world.xyz);
		
		normal= vertex.normal;
	#endif // MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	

	#ifndef pc

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
		prt_c0= dot(prt_component, prt_values) * 3.545f;

		float prt_scale= prt_c0 / PRT_C0_DEFAULT;
		prt_scale= lerp(0.6,1,prt_scale);
		front_face_lighting.xyz *= prt_scale;

		#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_flat	
			omnidirectional_lighting= front_face_lighting + back_face_lighting;
		#endif

	#endif // xenon
}

#endif // defined(entry_point_lighting)
