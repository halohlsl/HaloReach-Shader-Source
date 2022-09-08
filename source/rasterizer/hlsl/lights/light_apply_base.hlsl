////#line 1 "source\rasterizer\hlsl\light_apply.hlsl"


//@generate tiny_position
//@entry default
//@entry albedo
//@entry active_camo

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"
#include "shared\render_target.fx"
#include "shared\texture_xform.fx"
#include "shared\constants.fx"
#include "lights\light_apply_base_registers.fx"

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
#define LIGHT_COLOR		(light_colour_falloff_power.rgb)
//#define LIGHT_COLOR		(p_lighting_constant_4.rgb * texCUBE(gel_sampler, light_to_fragment_lightspace.xyz).rgb)
//#define LIGHT_COLOR		(p_lighting_constant_4.rgb * tex2D(gel_sampler, light_to_fragment_lightspace.xy / light_to_fragment_lightspace.z).rgb)
//#define LIGHT_COLOR			float3(1.0f, 0.0f, 0.0f)
#endif // LIGHT_COLOR

#ifndef DEFORM
#define DEFORM				deform_tiny_position
//#define DEFORM					deform_tiny_position_projective
#endif // DEFORM

#define pi 3.14159265358979323846


// p_lighting_constant_4 is the light color tint

#define LIGHT_FAR_ATTENUATION_END	(light_attenuation.x)
#define LIGHT_FAR_ATTENUATION_RATIO (light_attenuation.y)
#define LIGHT_COSINE_CUTOFF_ANGLE (light_attenuation.z)
#define LIGHT_ANGLE_FALLOFF_RAIO (light_attenuation.w)
#define LIGHT_ANGLE_FALLOFF_POWER (light_colour_falloff_power.w)

#define CAMERA_TO_LIGHT										(camera_to_light.xyz)



float3 calculate_relative_world_position(float2 texcoord, float depth)
{
	float4 clip_space_position= float4(texcoord.xy, depth, 1.0f);
	float4 world_space_position= mul(clip_space_position, transpose(screen_to_relative_world));
	return world_space_position.xyz / world_space_position.w;
}

void default_vs(
	in vertex_type vertex,
	out float4 screen_position : SV_Position)
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
	out float4 screen_position : SV_Position)
{
	default_vs(vertex, screen_position);
}

void active_camo_vs(
   in vertex_type vertex,
	out float4 screen_position : SV_Position)
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
#if defined(pc) && (DX_VERSION == 9)
 	color= 0.0f;
	camera_to_fragment= 0;
	normal= 0;
#else

	float3 light_to_fragment;
	float4 albedo;			// alpha channel is spec scale	(mask * coeff)
	{
		float depth;
#ifdef xenon
		asm
		{
			tfetch2D depth.x,	pixel_pos, depth_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
			tfetch2D normal,	pixel_pos, normal_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
			tfetch2D albedo,	pixel_pos, albedo_sampler,	UnnormalizedTextureCoords=true, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
		};
#elif DX_VERSION == 11
		depth.x= depth_sampler.t.Load(int3(pixel_pos, 0));
		normal= (normal_sampler.t.Load(int3(pixel_pos, 0)) * 2) - 1;
		albedo= albedo_sampler.t.Load(int3(pixel_pos, 0));
#endif
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
		angle_falloff= safe_pow(angle_falloff, LIGHT_ANGLE_FALLOFF_POWER);
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
		specular_lobe=				10 * sample2D(specular_curve_sampler, float2(half_dot_normal, normal.w));
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
		}
	}

	float3 irradiance= LIGHT_COLOR * distance_falloff * angle_falloff;

	color=	irradiance * COMBINE_LOBES( (cosine_lobe / pi), (specular_lobe.rgb), albedo);

#endif
}


SHADER_ATTRIBUTES
accum_pixel default_ps(
	in SCREEN_POSITION_INPUT(pixel_pos)) : SV_Target0
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

#ifndef pc

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

#define sample_percentage_closer_PCF sample_percentage_closer_PCF_cheap
#define sample_percentage_closer_hq_PCF sample_percentage_closer_PCF_cheap

#else

float sample_percentage_closer_PCF(float3 fragment_shadow_position, float depth_bias)
{
	float2 texel1= fragment_shadow_position.xy;

	float4 blend;

	float2 frac_pos = fragment_shadow_position.xy / pixel_size + float2(0.5f, 0.5f);
	blend.xy = frac(frac_pos);
	blend.zw= 1.0f - blend.xy;

#define offset_0 -1.5f
#define offset_1 -0.5f
#define offset_2 +0.5f
#define offset_3 +1.5f

	float3 max_depth= depth_bias;							// x= central samples,   y = adjacent sample,   z= diagonal sample
	max_depth *= float3(-2.0f, -sqrt(5.0f), -4.0f);			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	// 4x4 point and 3x3 bilinear
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_0).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_0).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_1).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_1).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_2).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_2).r) +
					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_3).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_3).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_3).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_3).r);

	color /= 9.0f;

	return color;
}

float sample_percentage_closer_hq_PCF(float3 fragment_shadow_position, float depth_bias)
{
	const float half_texel_offset = 0.5f;

	float2 texel1= fragment_shadow_position.xy;

	float4 blend;
   float2 frac_pos = fragment_shadow_position.xy / pixel_size + half_texel_offset;
   blend.xy = frac(frac_pos);
	blend.zw= 1.0f - blend.xy;

#define offset_0 (-4.0f + half_texel_offset)
#define offset_1 (-3.0f + half_texel_offset)
#define offset_2 (-2.0f + half_texel_offset)
#define offset_3 (-1.0f + half_texel_offset)
#define offset_4 (-0.0f + half_texel_offset)
#define offset_5 (-1.0f + half_texel_offset)
#define offset_6 (+2.0f + half_texel_offset)
#define offset_7 (+3.0f + half_texel_offset)

	float3 max_depth= depth_bias;							// x= central samples,   y = adjacent sample,   z= diagonal sample
	max_depth *= float3(-2.0f, -sqrt(5.0f), -4.0f);			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	// 8x8 point and 7x7 bilinear
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_0).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_0).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_1).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_1).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_2).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_2).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_3).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_3).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_4).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_4).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_5).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_5).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_6).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_6).r) +

					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_4, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_5, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_6, offset_7).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_7, offset_7).r);

	color /= 49.0f;

	return color;
}

#endif


SHADER_ATTRIBUTES
accum_pixel light_with_shadow_ps(
	in SCREEN_POSITION_INPUT(pixel_pos),
	bool high_res_shadow) : SV_Target0
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
		if (high_res_shadow)
		{
			unshadowed_percentage= sample_percentage_closer_hq_PCF(fragment_position_shadow, 0.0005);	// ###xwan, it's a really hack number, but make everything work!
		} else
		{
			unshadowed_percentage= sample_percentage_closer_PCF(fragment_position_shadow, 0.0005);	// ###xwan, it's a really hack number, but make everything work!
		}
		unshadowed_percentage= lerp(1.0f, unshadowed_percentage, screen_light_shadow_aux_constant_1.w);
	}
	color*= unshadowed_percentage;

	return convert_to_render_target(float4(color.rgb, 1.0f), false, true);
}

SHADER_ATTRIBUTES
accum_pixel albedo_ps(
	in SCREEN_POSITION_INPUT(pixel_pos)) : SV_Target0
{
	return light_with_shadow_ps(pixel_pos, false);
}

SHADER_ATTRIBUTES
accum_pixel active_camo_ps(
	in SCREEN_POSITION_INPUT(pixel_pos)) : SV_Target0
{
	return light_with_shadow_ps(pixel_pos, true);
}
