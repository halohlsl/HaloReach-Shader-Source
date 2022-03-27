/*
SCREEN_ATM_FOG.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
*/


#include "hlsl_constant_globals.fx"
#include "shared\blend.fx"
#include "shared\render_target.fx"

#define QUAD_INDEX_MOD4
#include "shared\procedural_geometry.fx"

#define FOG_ENABLED
#include "shared\atmosphere_core.fx"

#ifdef PIXEL_SHADER
	PIXEL_CONSTANT(s_atmosphere_constants, k_ps_atmosphere_constants, c200);
	PIXEL_CONSTANT(s_fog_light_constants, k_ps_atmosphere_fog_constants, c204);
	PIXEL_CONSTANT(s_atmosphere_precomputed_LUT_constants, k_ps_atmosphere_lut_constants, c232);
	PIXEL_CONSTANT(float4x4,	 k_ps_view_xform_inverse,	c213);			// ###XWAN ###CTCHOU $PERF make this c212...   don't straddle 4-constant boundaries if you don't have to
#endif // PIXEL_SHADER

#ifdef VERTEX_SHADER
	VERTEX_CONSTANT(float4x4, k_vs_camera_to_world, c16);
	VERTEX_CONSTANT(float4x4, k_vs_projective_to_world, c20);
	VERTEX_CONSTANT(float4x4, k_vs_camera_to_projective, c24);
	VERTEX_CONSTANT(float4x4, k_vs_world_to_projective, c28);
	
	VERTEX_CONSTANT(s_atmosphere_constants, k_vs_atmosphere_constants, c232);		// should lie on top of v_atmosphere_constant_0 / k_vs_atmosphere_constant_0
#endif // VERTEX_SHADER


//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@generate screen
//@entry albedo
//@entry default
//@entry static_sh
//@entry static_per_vertex
//@entry static_per_pixel


// rename entry points to more descriptive names
#define screen_atm_fog_strip_vs								default_vs
#define screen_atm_fog_strip_ps								default_ps
#define screen_atm_fog_with_lights_vs						static_sh_vs
#define screen_atm_fog_with_lights_ps						static_sh_ps
#define screen_atm_fog_with_desat_vs						static_per_vertex_vs
#define screen_atm_fog_with_desat_ps						static_per_vertex_ps
#define screen_atm_fog_with_lights_and_desat_vs				static_per_pixel_vs
#define screen_atm_fog_with_lights_and_desat_ps				static_per_pixel_ps
#define atmosphere_fog_table_vs								albedo_vs
#define atmosphere_fog_table_ps								albedo_ps


sampler k_ps_screen_atm_fog_sampler_depth_buffer : register(s1);
sampler k_ps_screen_atm_fog_sampler_color_buffer : register(s2);
sampler k_ps_screen_atm_fog_sampler_fog_table : register(s3);

struct s_fog_vertex
{
	int index		:	INDEX;
};

struct s_fog_interpolators
{
	float4 position					:POSITION0;
#ifndef pc
	float2 texcoord					:TEXCOORD0;
#endif // !pc
};

struct s_fog_apply_interpolators
{
	float4 position : POSITION;
};

#ifdef VERTEX_SHADER

	s_fog_apply_interpolators screen_quad_vs(s_fog_vertex IN)
	{	
		s_fog_apply_interpolators OUT;
#ifndef pc
		float2	subquad_pos=	generate_quad_point_2d(IN.index);							// 0..1
		float	quad_index=		floor(IN.index * 0.25f + 0.125f);							// 0..15
		
#define QUADS_X 8.0f
#define QUADS_Y 8.0f
		
		float2	quad_pos;
		quad_pos.y=						floor(quad_index * (1.0f / QUADS_X) + (0.5f / QUADS_X));
		quad_pos.x=						quad_index - quad_pos.y * QUADS_X;
		
		float4	projective_pos;
		projective_pos.xy=				(quad_pos + subquad_pos) * (2.0f / float2(QUADS_X, QUADS_Y)) - 1.0f;
		projective_pos.z=				1.0f;
		projective_pos.w=				1.0f;
		
		float4 world_pos=				mul(projective_pos, transpose(k_vs_projective_to_world));
		world_pos.xyz	/=				world_pos.w;
		
		float3 direction=				normalize(world_pos - Camera_Position);		// normalized direction of this camera ray
		float dist_z=					abs(1.0f / direction.z);					// how far the ray travels for every unit of z traversed

		float extinction_threshold=		k_vs_atmosphere_constants._fog_extinction_threshold;			// 0.99f;

		float fog_distance_bias=		-k_vs_atmosphere_constants._fog_distance_bias * 0.9f;

		float ray_distance;
		if (extinction_threshold < 1.0f)
		{
			float ray_distance_sky=				-log(extinction_threshold) / k_vs_atmosphere_constants._sky_fog_thickness;
			float distance_above_ground_fog=	Camera_Position.z - (k_vs_atmosphere_constants._ground_fog_height + k_vs_atmosphere_constants._ground_fog_base_height);
			
			if (distance_above_ground_fog > ray_distance_sky)
			{
				ray_distance=	ray_distance_sky;
			}
			else if (distance_above_ground_fog > 0.0f)
			{
				// add in distance to ground, and sky fog amount, remove from target extinction
				ray_distance=			distance_above_ground_fog;
				extinction_threshold /= compute_extinction(k_vs_atmosphere_constants._sky_fog_thickness, distance_above_ground_fog);
				
				float ray_distance_combined=	-log(extinction_threshold) / (k_vs_atmosphere_constants._sky_fog_thickness + k_vs_atmosphere_constants._ground_fog_thickness);		
				ray_distance  += ray_distance_combined;
			}
			else
			{
				ray_distance=	-log(extinction_threshold) / (k_vs_atmosphere_constants._sky_fog_thickness + k_vs_atmosphere_constants._ground_fog_thickness);
			}
		}
		else
		{
			ray_distance=	0;
		}
		
		ray_distance += fog_distance_bias;

		float3 world_position=	Camera_Position.xyz + max(ray_distance, 0.0001f) * direction;
			
		float4 projective_pos2=	mul(float4(world_position, 1.0f), transpose(k_vs_world_to_projective));
		projective_pos2.xyz /= projective_pos2.w;
			
		projective_pos.z=	saturate(projective_pos2.z);

		OUT.position.xyz=	projective_pos.xyz;
		OUT.position.w=		1.0f;	
		
#else // PC
		OUT.position=	0.0f;
#endif // PC

		return OUT;
	}

	s_fog_interpolators screen_quad_tex_vs(s_fog_vertex IN)
	{	
		float2 corner= generate_quad_point_2d(IN.index) * 2 - 1;

		s_fog_interpolators OUT;
	
#ifndef pc				
		OUT.position= float4(corner, 0, 1);
		const float buffer_resolution= 256;
		OUT.texcoord= corner*0.5f + 0.5f;	// range from [0, 0] to [1, 1]
		OUT.texcoord*= (buffer_resolution-1)/buffer_resolution;
		OUT.texcoord+= 0.5f/buffer_resolution;
#else // PC
		OUT.position=	0.0f;
#endif // PC

		return OUT;
	}

	s_fog_apply_interpolators screen_atm_fog_strip_vs(s_fog_vertex IN)							{	return screen_quad_vs(IN);	}
	s_fog_apply_interpolators screen_atm_fog_with_lights_vs(s_fog_vertex IN)					{	return screen_quad_vs(IN);	}
	s_fog_apply_interpolators screen_atm_fog_with_desat_vs(s_fog_vertex IN)						{	return screen_quad_vs(IN);	}
	s_fog_apply_interpolators screen_atm_fog_with_lights_and_desat_vs(s_fog_vertex IN)			{	return screen_quad_vs(IN);	}
	s_fog_interpolators atmosphere_fog_table_vs(s_fog_vertex IN)								{	return screen_quad_tex_vs(IN);	}

#endif // VERTEX_SHADER



#ifdef PIXEL_SHADER

	float3 get_pixel_world_position(
		in float2 fragment_pixel_position)
	{
#ifndef pc	
		// get depth
		float4 depth4f;
		asm {
			tfetch2D depth4f, fragment_pixel_position, k_ps_screen_atm_fog_sampler_depth_buffer, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true
		};
			
		float pixel_depth= depth4f.x;
		float4 pixel_position_4d= float4(fragment_pixel_position, pixel_depth, 1.0f);
		pixel_position_4d= mul(pixel_position_4d, transpose(k_ps_view_xform_inverse));
		pixel_position_4d.xyz/= pixel_position_4d.w;
		
		return pixel_position_4d.xyz;
#else	// pc
		return 0.0f;
#endif	// pc
	}
	

	float4 sample_and_apply_fog_with_desaturation(
		in float2 fragment_pixel_position,
		in float3 inscatter,
		in float extinction)
	{
#ifndef pc
//		float desaturation=		0.0f; // _fog_desaturation * (1.0-extinction);
	
		float4 pixel_color;
		asm 
		{
			tfetch2D pixel_color, fragment_pixel_position, k_ps_screen_atm_fog_sampler_color_buffer, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false 
		};
		
//		float3 out_color=		apply_desaturation(pixel_color.rgb, desaturation) * extinction + inscatter * BLEND_FOG_INSCATTER_SCALE * g_exposure.r;
		float3 out_color=		pixel_color.rgb * extinction + inscatter * BLEND_FOG_INSCATTER_SCALE * g_exposure.r;
		
		return float4(out_color.rgb, pixel_color.a);
#else	// pc
		return float4(0.2f, 0.3f, 0.4f, 1.0f);
#endif	// pc		
	}

	#ifdef pc
		float4 screen_atm_fog_with_lights_and_desat_ps(
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			return float4(0, 0, 0, 1);
		}

		float4 screen_atm_fog_with_desat_ps( 
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			return float4(0, 0, 0, 1);
		}

		float4 screen_atm_fog_with_lights_ps( 
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			return float4(0, 0, 0, 1);
		}

		float4 screen_atm_fog_strip_ps(
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			return float4(0, 0, 0, 1);
		}

		float4 atmosphere_fog_table_ps( 		
			in float3 fragment_position : VPOS,
			in s_fog_interpolators IN ) : COLOR
		{
			return float4(0, 1, 2, 3);
		}

	#else // xenon
		float4 screen_atm_fog_with_lights_and_desat_ps(
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			float3 world_position=		get_pixel_world_position(fragment_pixel_position);
			float4 scatter_parameters=	get_atmosphere_fog_optimized_LUT(k_ps_screen_atm_fog_sampler_fog_table, k_ps_atmosphere_lut_constants, k_ps_atmosphere_fog_constants, Camera_Position_PS, world_position, true, true);
			return sample_and_apply_fog_with_desaturation(fragment_pixel_position, scatter_parameters.rgb, scatter_parameters.a);
		}

		float4 screen_atm_fog_with_desat_ps( 
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			float3 world_position=		get_pixel_world_position(fragment_pixel_position);
			float4 scatter_parameters=	get_atmosphere_fog_optimized_LUT(k_ps_screen_atm_fog_sampler_fog_table, k_ps_atmosphere_lut_constants, k_ps_atmosphere_fog_constants, Camera_Position_PS, world_position, true, false);
			return sample_and_apply_fog_with_desaturation(fragment_pixel_position, scatter_parameters.rgb, scatter_parameters.a);
		}

		float4 screen_atm_fog_with_lights_ps( 
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			float3 world_position=		get_pixel_world_position(fragment_pixel_position);
			float4 scatter_parameters=	get_atmosphere_fog_optimized_LUT(k_ps_screen_atm_fog_sampler_fog_table, k_ps_atmosphere_lut_constants, k_ps_atmosphere_fog_constants, Camera_Position_PS, world_position, true, true);
			return	float4(scatter_parameters.rgb * BLEND_FOG_INSCATTER_SCALE * g_exposure.r,		scatter_parameters.a / 32.0f);
		}

		float4 screen_atm_fog_strip_ps(
			in float2 fragment_pixel_position : VPOS) : COLOR
		{
			float3 world_position=		get_pixel_world_position(fragment_pixel_position);
			float4 scatter_parameters=	get_atmosphere_fog_optimized_LUT(k_ps_screen_atm_fog_sampler_fog_table, k_ps_atmosphere_lut_constants, k_ps_atmosphere_fog_constants, Camera_Position_PS, world_position, true, false);
			return	float4(scatter_parameters.rgb * BLEND_FOG_INSCATTER_SCALE * g_exposure.r,		scatter_parameters.a / 32.0f);
		}

		// ---------------- implementation of fog table */
		float4 atmosphere_fog_table_ps( 		
			in float3 fragment_position : VPOS,
			in s_fog_interpolators IN ) : COLOR
		{	
			float view_point_z= Camera_Position_PS.z;

			float scene_point_z= LUT_get_z_from_coord(k_ps_atmosphere_lut_constants, 1.0f - IN.texcoord.y);
			float view_distance= IN.texcoord.x * IN.texcoord.x * k_ps_atmosphere_lut_constants.MAX_VIEW_DISTANCE;

			float3 inscatter;
			float extinction;
			compute_scattering_core(
				k_ps_atmosphere_constants,
				view_point_z, scene_point_z, view_distance, 
				inscatter, extinction);

			return float4(sqrt(inscatter), extinction);		//  * g_exposure.rrr
		}
	#endif //pc/xenon
	
#endif // PIXEL_SHADER



// end of rename macro
#undef screen_atm_fog_vs
#undef screen_atm_fog_ps
#undef atmosphere_fog_table_vs
#undef atmosphere_fog_table_ps

