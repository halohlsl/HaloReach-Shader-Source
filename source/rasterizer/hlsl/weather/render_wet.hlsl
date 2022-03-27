/*
WATER_WET.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
*/

//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@generate ripple
//@entry default
//@entry albedo

#include "shared\blend.fx"
#include "hlsl_constant_globals.fx"

#include "shared\render_target.fx"

// rename entry point of water passes 
#define screen_wet_vs		default_vs
#define screen_wet_ps		default_ps

#define screen_fog_vs		albedo_vs
#define screen_fog_ps		albedo_ps


#ifndef pc /* implementation of xenon version */


// shader constants define, please refer to weather\render_wet.cpp
VERTEX_CONSTANT(float4, k_vs_player_view_constant, c250);

PIXEL_CONSTANT(float4x4, k_ps_view_xform_inverse, c213);
PIXEL_CONSTANT(float4,	k_ps_camera_position_and_wet_coeff, c217);  // xyz camera position, w, wet coeff
PIXEL_CONSTANT(float4,	k_ps_ripple_scroll_coeff, c218);  // time, cubemap_blend_factor, , ,

sampler k_ps_wet_sampler_depth_buffer : register(s1);
sampler k_ps_wet_sampler_normal_buffer : register(s2);
sampler k_ps_wet_sampler_cubemap_0 : register(s3);
sampler k_ps_wet_sampler_cubemap_1 : register(s4);
sampler k_ps_wet_sampler_ripple : register(s5);

#define k_wet_effect_cut_off_distance	60

//	ignore the vertex_type, input vertex type defined locally
struct s_wet_vertex
{
	int index		:	INDEX;
};

struct s_wet_interpolators
{
	float4 position					:POSITION0;
	float4 texcoord_and_position	:TEXCOORD0;		// texcoord in LDR and depth buffer, and screen space position
};

#ifdef VERTEX_SHADER

static const float2 k_screen_corners[4]= { 
		float2(-1, -1), float2(1, -1), float2(1, 1), float2(-1, 1) };

s_wet_interpolators screen_quad_vs(s_wet_vertex IN)
{	
	float2 corner= k_screen_corners[IN.index];

	s_wet_interpolators OUT;
	OUT.position= float4(corner, 0, 1);

	// calcuate texcoord in screen space	
	float2 texcoord= corner / 2 + 0.5;
	texcoord.y= 1 - texcoord.y;
	texcoord= k_vs_player_view_constant.xy + texcoord*k_vs_player_view_constant.zw;
	OUT.texcoord_and_position.xy= texcoord;
	OUT.texcoord_and_position.zw= corner;

	return OUT;
}

s_wet_interpolators screen_wet_vs(s_wet_vertex IN)
{	
	return screen_quad_vs(IN);
}

s_wet_interpolators screen_fog_vs(s_wet_vertex IN)
{	
	return screen_quad_vs(IN);
}


#endif //VERTEX_SHADER

#ifdef PIXEL_SHADER

void get_current_pixel_distance_and_view_direction(
	in float2 texcoord,
	in float2 screen_position,
	out float3 pixel_normal,
	out float3 view_dir,
	out float distance,
	out float3 ripple_normal)
{
	float pixel_depth= tex2D(k_ps_wet_sampler_depth_buffer, texcoord).r;
	float4 pixel_position= float4(screen_position, pixel_depth, 1.0f);
	pixel_position= mul(pixel_position, k_ps_view_xform_inverse);
	pixel_position.xyz/= pixel_position.w;

	view_dir= k_ps_camera_position_and_wet_coeff.xyz - pixel_position.xyz;
	distance= length(view_dir);
	view_dir/= distance;	// normalize

	// get pixel normal
	pixel_normal= tex2D(k_ps_wet_sampler_normal_buffer, texcoord.xy).rgb;
	pixel_normal= normalize(pixel_normal.xyz * 2.0f - 1.0f);

	float3 ripple_texcoord;

	// get ripple normal
	const float game_time= k_ps_ripple_scroll_coeff.x;
	{
		const float3 direction_up= float3(0, 0, 1);
		float3 flood_dir= 0;
		[branch]
		if (pixel_normal.z < 0.98)
		{
			flood_dir= cross(direction_up, pixel_normal);
			flood_dir= cross(flood_dir, direction_up);
			flood_dir= normalize(flood_dir);	
		}
		
		ripple_texcoord.xy= pixel_position.xy*float2(0.72721, 0.335793) - float2(0.795793, 0.57721)*game_time * flood_dir.xy;
		ripple_texcoord.z= game_time * 1.17239;
		ripple_texcoord*= 2.1717;

		float3 ripple_normal_0= tex3Dlod(k_ps_wet_sampler_ripple, float4(ripple_texcoord, 1)).xyz;
		ripple_normal_0= ripple_normal_0 * 2.0f - 1.0f;		

		ripple_texcoord.xy= pixel_position.xy*float2(0.62721, 0.435793) - float2(0.595793, 0.52721)*game_time * flood_dir.xy;
		ripple_texcoord.z= game_time * 0.97239;
		ripple_texcoord*= 1.71773;

		float3 ripple_normal_1= tex3Dlod(k_ps_wet_sampler_ripple, float4(ripple_texcoord, 1)).xyz;
		ripple_normal_1= ripple_normal_1 * 2.0f - 1.0f;

		ripple_normal= ripple_normal_0 * ripple_normal_1;		
		ripple_normal.z= 0;	
	}	
}


#define flooding_tile_threshold		0.1


void get_current_pixel_normal_and_reflect_color(
	in float2 texcoord,
	in float3 view_dir,
	in float3 ripple_normal,
	in float3 pixel_normal,
	out float3 reflection_color)
{
	[branch]
	if (pixel_normal.z > flooding_tile_threshold)
	{
		//const float ripple_weight= (pixel_normal.z - flooding_tile_threshold) / (1.0f - flooding_tile_threshold);
		const float ripple_weight= 1;
		pixel_normal+=ripple_normal *ripple_weight * 0.5f;
		pixel_normal= normalize(pixel_normal);
	}

	// reflect
	float view_dot_normal=	dot(view_dir, pixel_normal);	
	float3 reflect_dir= (view_dot_normal * pixel_normal - view_dir) * 2 + view_dir;


	const float cubemap_blend_factor= k_ps_ripple_scroll_coeff.y;
	float4 reflection_0= texCUBElod(k_ps_wet_sampler_cubemap_0, float4(reflect_dir, 0)); 
	float4 reflection_1= texCUBElod(k_ps_wet_sampler_cubemap_1, float4(reflect_dir, 0)); 
	reflection_0.rgb= reflection_0.rgb * reflection_0.a * 256;
	reflection_1.rgb= reflection_1.rgb * reflection_1.a * 256;

	reflection_color= lerp(reflection_0.rgb, reflection_1.rgb, cubemap_blend_factor);
	reflection_color*= 0.02;
}

#define k_max_brdf_dim_coeff_by_wet 0.6f


accum_pixel screen_wet_ps( s_wet_interpolators IN )
{	
	float3 pixel_normal;
	float distance;
	float3 view_dir;
	float3 ripple_normal;
	get_current_pixel_distance_and_view_direction(
		IN.texcoord_and_position.xy, IN.texcoord_and_position.zw, pixel_normal, view_dir, distance, ripple_normal);	

	float3 output_color;
	float wet_coeff;
	[branch]
	if (distance > k_wet_effect_cut_off_distance) 
	{
		wet_coeff= 0;
		output_color= 0;
	}	
	else 
	{			
		float3 reflection_color;
		get_current_pixel_normal_and_reflect_color(
			IN.texcoord_and_position.xy, view_dir, ripple_normal, pixel_normal, reflection_color);		

		wet_coeff= k_max_brdf_dim_coeff_by_wet;
		float3 half_dir= normalize(pixel_normal + view_dir);
		float h_dot_v= dot(half_dir, view_dir);
		float fresnel_coeff= 0.3f + 0.7f*pow((1 - h_dot_v), 2.0);		
		output_color= reflection_color.xyz * fresnel_coeff;				

		wet_coeff+= fresnel_coeff * (1.0f - k_max_brdf_dim_coeff_by_wet);

		// consider global wet coeff
		const float global_wet_coeff= sqrt(k_ps_camera_position_and_wet_coeff.w);
		wet_coeff*= global_wet_coeff;
		output_color*= global_wet_coeff;
	
	}

	return convert_to_render_target(float4(output_color, wet_coeff), true, true);
}


accum_pixel screen_fog_ps( s_wet_interpolators IN )
{	
	float3 pixel_normal;
	float distance;
	float3 view_dir;
	float3 ripple_normal;
	float pixel_depth= tex2D(k_ps_wet_sampler_depth_buffer, IN.texcoord_and_position.xy).r;
	float4 pixel_position= float4(IN.texcoord_and_position.zw, pixel_depth, 1.0f);
	pixel_position= mul(pixel_position, k_ps_view_xform_inverse);
	pixel_position.xyz/= pixel_position.w;

	view_dir= k_ps_camera_position_and_wet_coeff.xyz - pixel_position.xyz;
	distance= length(view_dir);
	view_dir/= distance;	// normalize

	float fog_coeff= 0;
	if (pixel_position.z < 0.3f && view_dir.z > 0)
	{
		const float travel_distance= (0.3f - pixel_position.z) / abs(view_dir.z);
		fog_coeff= saturate(travel_distance);

		const float game_time= k_ps_ripple_scroll_coeff.x;
		float3 ripple_texcoord;
		ripple_texcoord.xy= pixel_position.xy*float2(0.12721, 0.133579) - game_time * float2(0.012721, 0.0135793);
		ripple_texcoord.z= game_time * 0.27239;
		float3 ripple_normal= tex3Dlod(k_ps_wet_sampler_ripple, float4(ripple_texcoord, 3)).xyz;
		ripple_normal= ripple_normal * 2.0f - 1.0f;

		fog_coeff= saturate(fog_coeff+ 0.5*ripple_normal.x);
	}	

	float3 output_color= fog_coeff * 0.01f;	
	return convert_to_render_target(float4(output_color, fog_coeff), true, true);
}


#endif //PIXEL_SHADER

#else /* implementation of pc version */

struct s_wet_interpolators
{
	float4 position	:POSITION0;
};

s_wet_interpolators screen_wet_vs()
{
	s_wet_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

s_wet_interpolators screen_fog_vs()
{
	s_wet_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 screen_wet_ps(s_wet_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

float4 screen_fog_ps(s_wet_interpolators INTERPOLATORS) :COLOR0
{
	return float4(0,1,2,3);
}

#endif //pc/xenon

// end of rename marco
#undef wet_surface_vs
#undef wet_surface_ps
