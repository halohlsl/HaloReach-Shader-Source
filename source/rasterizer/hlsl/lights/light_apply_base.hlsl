////#line 1 "source\rasterizer\hlsl\light_apply.hlsl"


//@generate tiny_position
//@entry default
//@entry albedo

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"

#include "shared\render_target.fx"

#include "shared\texture_xform.fx"

#include "shared\constants.fx"

// default parameters

#ifndef COMBINE_LOBES
//#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo) (cosine_lobe * albedo.rgb + specular_lobe * albedo.a)
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo) (cosine_lobe * albedo.rgb)
#endif // COMBINE_LOBES

#ifndef SHADER_ATTRIBUTES
#define SHADER_ATTRIBUTES /*[maxtempreg(3)]*/
#endif // SHADER_ATTRIBUTES

// light color should include exposure (and fog approximation?)
#ifndef LIGHT_COLOR
#define LIGHT_COLOR		(p_lighting_constant_4.rgb)
//#define LIGHT_COLOR		(p_lighting_constant_4.rgb * texCUBE(gel_sampler, light_to_fragment_lightspace.xyz).rgb)
//#define LIGHT_COLOR		(p_lighting_constant_4.rgb * tex2D(gel_sampler, light_to_fragment_lightspace.xy / light_to_fragment_lightspace.z).rgb)
//#define LIGHT_COLOR			float3(1.0f, 0.0f, 0.0f)
#endif // LIGHT_COLOR

#ifndef DEFORM
#define DEFORM				deform_tiny_position
//#define DEFORM					deform_tiny_position_projective
#endif // DEFORM

#define pi 3.14159265358979323846

sampler depth_sampler : register(s0);
sampler albedo_sampler : register(s1);
sampler normal_sampler : register(s2);
sampler specular_curve_sampler : register(s3);
sampler gel_sampler : register(s4);


PIXEL_CONSTANT(float4x4, screen_to_relative_world, c1);		// p_lighting_constant_0 - p_lighting_constant_3,	maps (pixel, depth) to world space coordinates with the origin at the light center

// p_lighting_constant_4 is the light color tint

#define LIGHT_FAR_ATTENUATION_END	(p_lighting_constant_5.x)
#define LIGHT_FAR_ATTENUATION_RATIO (p_lighting_constant_5.y)
#define LIGHT_COSINE_CUTOFF_ANGLE (p_lighting_constant_5.z)
#define LIGHT_ANGLE_FALLOFF_RAIO (p_lighting_constant_5.w)
#define LIGHT_ANGLE_FALLOFF_POWER (p_lighting_constant_4.w)

#define CAMERA_TO_LIGHT										(p_lighting_constant_6.xyz)

PIXEL_CONSTANT(float3x3, light_rotation, c8);				// p_lighting_constant_7 - p_lighting_constant_9

PIXEL_CONSTANT(float4, specular_color_normal, c11);  //w : specular steepness
PIXEL_CONSTANT(float4, specular_color_gazing, c12);  //w: specular coeff
PIXEL_CONSTANT(float4, material_coeff, c13);   //x: diffuse, y: roughness offset, z: albedo blend, w: NONE

PIXEL_CONSTANT(float, cheap_albedo_blend, c13);


PIXEL_CONSTANT(float4x4, screen_light_shadow_matrix, c200);
PIXEL_CONSTANT(float4, screen_light_shadow_aux_constant_0, c204);
PIXEL_CONSTANT(float4, screen_light_shadow_aux_constant_1, c205);
sampler	shadow_depth_map_1	: register(s5);


float3 calculate_relative_world_position(float2 texcoord, float depth)
{
	float4 clip_space_position= float4(texcoord.xy, depth, 1.0f);
	float4 world_space_position= mul(clip_space_position, transpose(screen_to_relative_world));
	return world_space_position.xyz / world_space_position.w;
}

void default_vs(
	in vertex_type vertex,
	out float4 screen_position : POSITION)
{
    float4 local_to_world_transform[3];
	if (always_true)
	{
		DEFORM(vertex, local_to_world_transform);
	}
	
	if (always_true)
	{
		screen_position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
	}
	else
	{
		screen_position= float4(0,0,0,0);
	}
}

void albedo_vs(
   in vertex_type vertex,
	out float4 screen_position : POSITION)
{
	default_vs(vertex, screen_position);
}


//	distance=					saturate(distance * LIGHT_DISTANCE_FALLOFF.x + LIGHT_DISTANCE_FALLOFF.y);
//	float distance_falloff=		clamped_distance;
//	float distance_falloff=		(2 - clamped_distance) * clamped_distance;
//	float distance_falloff=		saturate(((LIGHT_DISTANCE_FALLOFF.x * distance + LIGHT_DISTANCE_FALLOFF.y) * distance + LIGHT_DISTANCE_FALLOFF.z) * distance + LIGHT_DISTANCE_FALLOFF.w);
//	float distance_falloff=		saturate(LIGHT_DISTANCE_FALLOFF.x * distance + LIGHT_DISTANCE_FALLOFF.y);
//	float distance_falloff= 1 / (LIGHT_SIZE + distance2);											// distance based falloff				(2 instructions)
//	distance_falloff= max(0.0f, distance_falloff * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);		// scale, offset, clamp result			(2 instructions)	


void light_calculation(
   in float2 pixel_pos,
   out float3 color,
   out float3 camera_to_fragment,
   out float4 normal)
{
#ifdef pc
 	color= 0.0f;
	camera_to_fragment= 0;
	normal= 0;
#else

	float3 light_to_fragment;		
	float4 albedo;			// alpha channel is spec scale	(mask * coeff)
	{
		float depth;
		asm
		{
			tfetch2D depth.x,	pixel_pos, depth_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
			tfetch2D normal,	pixel_pos, normal_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
			tfetch2D albedo,	pixel_pos, albedo_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
		};		
		albedo.w*=albedo.w;
		light_to_fragment=	calculate_relative_world_position(pixel_pos, depth);	
		camera_to_fragment= CAMERA_TO_LIGHT + light_to_fragment;
	}

	// convert from worldspace to lightspace
	float3 light_to_fragment_lightspace= mul(light_to_fragment, light_rotation);
	
	[isolate]
	float distance_falloff, cosine_lobe, angle_falloff;
	{	
		float distance2=		dot(light_to_fragment, light_to_fragment);
		float distance= sqrt(distance2);
		light_to_fragment=		light_to_fragment / distance;
		

		//float distance=			saturate(sqrt(distance2) * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);
//		float distance=			saturate(light_to_fragment_lightspace.z * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);		// 'straight' non-spherical falloff

		cosine_lobe=			saturate(dot(-light_to_fragment, normal) + diffuse_light_cosine_raise );			//  * LIGHT_FALLOFF_SCALE + LIGHT_DIFFUSE_OFFSET);	
#ifdef USE_EXPENSIVE_MATERIAL
		cosine_lobe*= material_coeff.x;
#endif

		distance_falloff=		saturate((LIGHT_FAR_ATTENUATION_END - distance) * LIGHT_FAR_ATTENUATION_RATIO);
		distance_falloff*=distance_falloff;
		angle_falloff= saturate((light_to_fragment_lightspace.z/distance - LIGHT_COSINE_CUTOFF_ANGLE ) * LIGHT_ANGLE_FALLOFF_RAIO);
		angle_falloff= pow(angle_falloff, LIGHT_ANGLE_FALLOFF_POWER);
	}
	
	float3 specular_lobe;
	{
		// phong lobe
		
#if 1
		float3 view_dir=			-normalize(camera_to_fragment);
		float view_dot_normal=		dot(view_dir, normal);
		float3 view_reflect_dir=	view_dot_normal * normal * 2 - view_dir;
		
		
		if (normal.w<1)
		{
			float specular_power= 50 - ( 50 - 8 ) * normal.w / 0.66f;
			
			//specular_lobe= specular_model(view_dir, view_dot_normal, view_reflect_dir, specular_power, light_to_fragment);
			
			float specular_cosine_lobe= saturate(dot(-light_to_fragment, view_reflect_dir));
			
#ifdef USE_EXPENSIVE_MATERIAL
			float fresnel_blend= saturate(pow((1.0f - view_dot_normal ), specular_color_normal.w)); 
			float restored_specular_power= max(0,material_coeff.y + specular_power);
			
		    float3 normal_specular_blend_albedo_color= lerp(specular_color_normal.xyz, albedo.xyz, material_coeff.z);
			float3 final_specular_color= lerp(normal_specular_blend_albedo_color, specular_color_gazing, fresnel_blend);
			
			float power_result= pow(specular_cosine_lobe, restored_specular_power);
			
			specular_lobe= power_result * (1+restored_specular_power) * final_specular_color;
			
#else
			float3 final_specular_color= lerp(float3(1,1,1), albedo.xyz, cheap_albedo_blend);
			
			specular_lobe= pow(specular_cosine_lobe, specular_power) * (1+specular_power) * final_specular_color;
#endif
			
			//specular_lobe=				tex1D(albedo_sampler, dot(-light_to_fragment, view_reflect_dir));
		}
		else
		{
			specular_lobe= 0;
		}

#else
		// blinn-phong lobe
		float3 half_to_fragment=	normalize(light_to_fragment + normalize(camera_to_fragment));
		float half_dot_normal=		saturate(dot(-half_to_fragment, normal));

//		specular_lobe=				pow(half_dot_normal, specular_power) * specular_power;
		specular_lobe=				10 * tex2D(specular_curve_sampler, float2(half_dot_normal, normal.w));
#endif
	}
	
	{
		[predicateBlock]
		if (normal.w > 0.9f)
		{
			albedo.rgba= float4(0.09, 0.09f, 0.09f, 0.0f);
		}
		else
		{
			asm
			{
			};
		}
	}
	
	float3 irradiance= LIGHT_COLOR * distance_falloff * angle_falloff;
	
	color=	irradiance * COMBINE_LOBES( (cosine_lobe / pi), (specular_lobe.rgb), albedo);
	
#endif
}


SHADER_ATTRIBUTES
accum_pixel default_ps(
	in float2 pixel_pos : VPOS)
{
	float3 color;
	float3 camera_to_fragment;
	float4 normal;
	light_calculation(
		pixel_pos, color, camera_to_fragment,normal);   
	
	return convert_to_render_target(float4(color.rgb, 1.0f), false, true);
}


#define pixel_size			screen_light_shadow_aux_constant_1
#include "shared\texture.fx"


float sample_percentage_closer_PCF_cheap(float3 fragment_shadow_position, float depth_bias)					// 9 samples, 0 predicated
{
	float2 texel= fragment_shadow_position.xy;
	
	float max_depth= fragment_shadow_position.z *(1 + depth_bias);
	
	float shadow_ngbr=	step(max_depth, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, -1.0f).r) + 					
						step(max_depth, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, -1.0f).r) +
						step(max_depth, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +1.0f).r) +					
						step(max_depth, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +1.0f).r);
					
	return shadow_ngbr*0.25f;					
}


SHADER_ATTRIBUTES
accum_pixel albedo_ps(
	in float2 pixel_pos : VPOS)
{
	float3 color;
	float3 camera_to_fragment;
	float4 normal;
	light_calculation(
		pixel_pos, color, camera_to_fragment,normal);

	float3 fragment_position_world= Camera_Position_PS + camera_to_fragment;

	float4 fragment_position_shadow= mul(float4(fragment_position_world, 1.0f), screen_light_shadow_matrix);
	fragment_position_shadow.xyz/= fragment_position_shadow.w;


	// calculate shadow
	float unshadowed_percentage= 1.0f;	
	{		
		unshadowed_percentage= sample_percentage_closer_PCF_cheap(fragment_position_shadow, 0.0005);	// ###xwan, it's a really hack number, but make everything work!
		unshadowed_percentage= lerp(1.0f, unshadowed_percentage, screen_light_shadow_aux_constant_1.w);
	}
	color*= unshadowed_percentage;
	
	return convert_to_render_target(float4(color.rgb, 1.0f), false, true);
}