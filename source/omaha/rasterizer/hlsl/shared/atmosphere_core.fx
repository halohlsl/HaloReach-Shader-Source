#ifndef __ATMOSPHERE_CORE_FX_H__
#define __ATMOSPHERE_CORE_FX_H__


// lut mapping
#include "shared\atmosphere_structs.fx"
#include "shared\atmosphere_lut.fx"

#ifndef FOG_ENABLED
	FOG_SHOULD_ALWAYS_BE_ENABLED_JUST_DONT_CALL_IT_IF_YOU_DONT_WANT_IT
#endif //!FOG_ENABLED



float3 fog_light_color(
	uniform s_fog_light_constants fog_constants,
	in float3 view_direction)
{
	float cosine=		dot(view_direction, fog_constants._fog_light_1_direction);
	float ratio=		saturate( cosine * fog_constants._fog_light_1_radius_scale + fog_constants._fog_light_1_radius_offset );
	return				fog_constants._fog_light_1_color * pow(ratio, fog_constants._fog_light_1_angular_falloff);
}



float compute_extinction(
		const float thickness,
		const float dist)
{
	// 7 ALU, hard to be parallalized
	return saturate(exp( -thickness * dist));			// ###XWAN $TODO $PERF use exp2 instead
}

float get_fog_thickness_at_relative_height(
	in float point_relative_height,
	in float fog_height,
	in float fog_thickness)
{
	// 5 ALU, could be parallal for vector operation
	float weight= saturate( (fog_height - point_relative_height)/fog_height );
	weight*= weight;
	return fog_thickness*weight;
}

float calc_solo_fog_extinction(
	in float view_distance,
	in float view_height_top,
	in float view_height_bottom,
	in float view_height_diff,
	in float fog_height,
	in float fog_base_height,
	// current fog
	in float fog_thickness,
	in float3 fog_color,
	in float fog_max_distance,
	in float fog_distance_bias,
	out float fog_actual_travel_distance)
{
	view_height_top		-=	fog_base_height;
	view_height_bottom	-=	fog_base_height;

	view_height_top= min(view_height_top, fog_height);
	float dist_ratio_in_fog= saturate ( (view_height_top-view_height_bottom)/view_height_diff );
	float approx_relative_height= lerp(view_height_bottom, view_height_top, 0.0f);
	//float approx_relative_height= view_height_bottom;
	float approx_thickness= get_fog_thickness_at_relative_height(approx_relative_height, fog_height, fog_thickness);

	//add bias
	float fog_view_distance= view_distance*dist_ratio_in_fog;
	fog_view_distance= max(fog_view_distance + fog_distance_bias, 0.0f);
	fog_view_distance= min(fog_view_distance, fog_max_distance);

	fog_actual_travel_distance= fog_view_distance;

	return compute_extinction(approx_thickness, fog_view_distance);
}


float calc_mixed_fog_extinction(
	in float view_distance,
	in float view_height_top,
	in float view_height_bottom,
	in float view_height_diff,
	in float fog_height,
	in float fog_base_height,
	// current fog
	in float fog_thickness,
	in float3 fog_color,
	in float fog_max_distance,
	// base fog
	in float base_fog_thickness,
	in float3 base_fog_color,
	in float base_fog_max_distance,
	in float fog_distance_bias,
	out float3 mixed_fog_color)
{
	view_height_top-= fog_base_height;
	view_height_bottom-= fog_base_height;

	view_height_top= min(view_height_top, fog_height);
	float dist_ratio_in_fog= saturate ( (view_height_top-view_height_bottom)/view_height_diff );
	float approx_relative_height= lerp(view_height_bottom, view_height_top, 0.0f);
	//float approx_relative_height= view_height_bottom;
	float approx_thickness= get_fog_thickness_at_relative_height(approx_relative_height, fog_height, fog_thickness);

	float fog_view_distance= view_distance*dist_ratio_in_fog;
	fog_view_distance= max(fog_view_distance + fog_distance_bias, 0.0f);

	float base_fog_view_distance= min(fog_view_distance, base_fog_max_distance);
	fog_view_distance= min(fog_view_distance, fog_max_distance);

	float fog_extinction=		compute_extinction(approx_thickness, fog_view_distance );
	float base_fog_extinction=	compute_extinction(base_fog_thickness, base_fog_view_distance);

	const float weight= approx_thickness * fog_view_distance;
	const float base_weight= base_fog_thickness * base_fog_view_distance;

	mixed_fog_color=  (fog_color*weight + base_fog_color*base_weight)/max((weight + base_weight), 0.00001f);
	return fog_extinction * base_fog_extinction;
}


void compute_scattering_core(
	uniform s_atmosphere_constants constants,
	in float view_point_z,
	in float scene_point_z,
	in float view_distance,
	out float3 inscatter,
	out float extinction)
{
	const float view_height_top= max(view_point_z, scene_point_z) + 0.001f;
	const float view_height_bottom= min(view_point_z, scene_point_z);
	const float view_height_diff= view_height_top - view_height_bottom;
	const float ground_fog_absolute_height= constants._ground_fog_height + constants._ground_fog_base_height;

	// tweak ground fog color
	float fog_actual_travel_distance;
	const float sky_fog_extinction= calc_solo_fog_extinction(
		view_distance,
		view_height_top, max(view_height_bottom, ground_fog_absolute_height), view_height_diff,
		constants._sky_fog_height,
		constants._sky_fog_base_height,
		constants._sky_fog_thickness,
		constants._sky_fog_color,
		constants._sky_fog_max_distance,
		constants._fog_distance_bias,
		fog_actual_travel_distance);

	float3 mixed_fog_color;
	const float mixed_fog_extinction= calc_mixed_fog_extinction(
		view_distance,
		min(view_height_top, ground_fog_absolute_height), view_height_bottom, view_height_diff,
		constants._ground_fog_height,
		constants._ground_fog_base_height,
		constants._ground_fog_thickness,
		constants._ground_fog_color,
		constants._ground_fog_max_distance,
		constants._sky_fog_thickness,
		constants._sky_fog_color,
		constants._sky_fog_max_distance - fog_actual_travel_distance,
		constants._fog_distance_bias,
		mixed_fog_color);

	const float3 sky_fog_inscatter= lerp(constants._sky_fog_color, 0, sky_fog_extinction);
	const float3 mixed_fog_inscatter= lerp(mixed_fog_color, 0, mixed_fog_extinction);

	extinction= sky_fog_extinction * mixed_fog_extinction;
	float3 inscatter_a=
			sky_fog_inscatter * mixed_fog_extinction +
			mixed_fog_inscatter;
	float3 inscatter_b=
			sky_fog_inscatter +
			mixed_fog_inscatter * sky_fog_extinction;

	float low_rate= ((ground_fog_absolute_height - view_point_z)/constants._ground_fog_height);
	low_rate= (low_rate * constants._ground_fog_thickness/max(constants._sky_fog_thickness, 0.00001f) );
	low_rate= saturate(low_rate);

	inscatter= lerp(inscatter_b, inscatter_a, low_rate);
}




float4 get_atmosphere_fog(					// returns (inscatter.rgb, monochrome_extinction)
	uniform s_atmosphere_constants constants,
	uniform s_fog_light_constants fog_constants,
	in float3 camera_position,
	in float3 world_position,
	const bool fog_enable,
	const bool fog_lights)
{
#if defined(xenon) || (DX_VERSION == 11)
	[branch]
	if (fog_enable)
	{
		float4 scatter_parameters;

		float3 view_direction= world_position - camera_position;
		normalize(view_direction);

		compute_scattering_core(
			constants,
			camera_position.z,
			world_position.z,
			view_direction,
			scatter_parameters.rgb,
			scatter_parameters.a);

		if (fog_lights)
		{
			float fog_light_scale=	(1.0f - scatter_parameters.a);
			fog_light_scale= saturate((fog_light_scale - fog_constants._fog_light_1_nearby_cutoff)/(1.0f - fog_constants._fog_light_1_nearby_cutoff));
			fog_light_scale= pow(max(fog_light_scale, 0.0000001), fog_constants._fog_light_1_distance_falloff);

			scatter_parameters.rgb	+= fog_light_scale * fog_light_color(fog_constants, view_direction);
		}
		return scatter_parameters;
	}
	else
#endif // xenon
	{
		return float4(0.0f, 0.0f, 0.0f, 1.0f);
	}
}



float4 get_atmosphere_fog_optimized_LUT(					// returns (inscatter.rgb, monochrome_extinction)
	texture_sampler_2d fog_table_sampler,
	uniform s_atmosphere_precomputed_LUT_constants constants,
	uniform s_fog_light_constants fog_constants,
	in float3 camera_position,
	in float3 world_position,
	uniform bool fog_enable,
	uniform bool fog_lights)
{
#if defined(xenon) || (DX_VERSION == 11)
	[branch]
	if (fog_enable)
	{
		float4 scatter_parameters;

		float3	view_direction=			world_position - camera_position;
		float	view_distance=			length(view_direction);
		view_direction/=				view_distance;

		float2 LUT_coord;
		LUT_coord.x=					LUT_get_x_coord(constants, camera_position, view_distance, world_position.z);
		LUT_coord.y=					LUT_get_y_coord(constants, world_position.z);									// ###XWAN $TODO $PERF remove this inversion, flip it in the generation of the texture!

#ifdef XENON
		asm
		{
			tfetch2D scatter_parameters, LUT_coord, fog_table_sampler, MagFilter=linear, MinFilter=linear, MipFilter=point, AnisoFilter=disabled, UnnormalizedTextureCoords= false, UseComputedLOD=false, UseRegisterLOD=false
		};
#else
		scatter_parameters= sample2Dlod(fog_table_sampler, LUT_coord, 0);
#endif

		scatter_parameters.rgb *= scatter_parameters.rgb;

		if (fog_lights)
		{
			float fog_light_scale=	(1.0f - scatter_parameters.a);
			fog_light_scale= saturate((fog_light_scale - fog_constants._fog_light_1_nearby_cutoff)/(1.0f - fog_constants._fog_light_1_nearby_cutoff));
			fog_light_scale= pow(max(fog_light_scale, 0.0000001), fog_constants._fog_light_1_distance_falloff);

			scatter_parameters.rgb	+= fog_light_scale * fog_light_color(fog_constants, view_direction);
		}
		return scatter_parameters;
	}
	else
#endif // xenon
	{
		return float4(0.0f, 0.0f, 0.0f, 1.0f);
	}
}


#endif // __ATMOSPHERE_CORE_FX_H__