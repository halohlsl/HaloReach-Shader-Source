/*
SCREEN_ATM_FOG.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
*/

//This comment causes the shader compiler to be invoked for certain vertex types and entry points
//@generate screen
//@entry default
//@entry albedo

// -----------------------------------------------------------------------
// header/defines
// -----------------------------------------------------------------------
#include "hlsl_constant_globals.fx"
#include "shared\blend.fx"

#include "shared\render_target.fx"

#define	PATCHY_EFFECT_ON_PLANAR_FOG
	#include "explicit\patchy_effect.fx"
#undef	PATCHY_EFFECT_ON_PLANAR_FOG

#include "explicit\planar_fog_registers.fx"

// rename entry point of water passes
#define planar_fog_vs					default_vs
#define planar_fog_ps					default_ps
#define planar_fog_full_screen_vs		albedo_vs
#define planar_fog_full_screen_ps		albedo_ps

// -----------------------------------------------------------------------
// implementation
// -----------------------------------------------------------------------
#if !defined(pc) || (DX_VERSION == 11) /* implementation of xenon version */

#define _planar_fog_color						k_ps_planar_fog_settings_0.xyz
#define _planar_fog_thickness					k_ps_planar_fog_settings_0.w
#define _planar_fog_plane_coeffs				k_ps_planar_fog_settings_1
#define _planar_fog_one_over_base_depth			k_ps_planar_fog_settings_2.x
#define _camera_position_in_fog_depth			k_ps_planar_fog_settings_2.y

#define	_planar_fog_palette_color_intensity		k_ps_planar_fog_palette_settings.y

struct s_fog_interpolators
{
	float4 position					:SV_Position0;
	float4 position_in_screen		:TEXCOORD0;
	float3 position_in_world		:TEXCOORD1;
};


struct s_fog_vertex
{
	uint index			:	SV_VertexID;
	float3 position		:	POSITION;
};

#ifdef VERTEX_SHADER

	s_fog_interpolators planar_fog_vs(s_fog_vertex IN)
	{
		s_fog_interpolators OUT;
		OUT.position= mul(float4(IN.position, 1.0f), View_Projection);
		OUT.position_in_screen= OUT.position;
		OUT.position_in_world= IN.position;
		return OUT;
	}


	static const float2 k_screen_corners[4]= {
		float2(-1, -1), float2(1, -1), float2(1, 1), float2(-1, 1) };

	s_fog_interpolators planar_fog_full_screen_vs(s_fog_vertex IN)
	{
		float2 corner= k_screen_corners[IN.index];

		s_fog_interpolators OUT;
		OUT.position= float4(corner, 0, 1);
		OUT.position_in_screen= OUT.position;
		OUT.position_in_world= OUT.position;
		return OUT;
	}


#endif //VERTEX_SHADER

#ifdef PIXEL_SHADER

	void get_current_pixel_info(
		in float2 fragment_position_in_pixel,
		in float2 screen_position,
		out float3 out_position)
	{
		// get color and depth
		float4 depth4f;
#ifdef XENON
		asm {
			tfetch2D depth4f, fragment_position_in_pixel, k_ps_planar_fog_sampler_depth_buffer, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true
		};
#elif DX_VERSION == 11
		depth4f= k_ps_planar_fog_sampler_depth_buffer.t.Load(int3(fragment_position_in_pixel, 0));
#endif

		float pixel_depth= depth4f.x;
		float4 pixel_position_4d= float4(screen_position, pixel_depth, 1.0f);
		pixel_position_4d= mul(pixel_position_4d, transpose(k_ps_view_xform_inverse));
		pixel_position_4d.xyz/= pixel_position_4d.w;
		out_position= pixel_position_4d.xyz;
	}

	float compute_extinction(
			const float thickness,
			const float dist)
	{
		return saturate(1.0f / exp(thickness * dist));
	}

	accum_pixel calculate_planar_fog(
		in float2 fragment_position_in_pixel,
		in s_fog_interpolators IN,
		const bool use_fog_geometry_to_evaluate_depth)  // hack the curved surface
	{
		// fetch position of pixel
		float3 pixel_position;
		get_current_pixel_info(
			fragment_position_in_pixel, IN.position_in_screen.xy/IN.position_in_screen.w,
			pixel_position);


		float depth_in_fog;
		[branch]
		if (use_fog_geometry_to_evaluate_depth)
		{
			float3 sight_vector= pixel_position - IN.position_in_world;
			depth_in_fog= dot(sight_vector, _planar_fog_plane_coeffs.xyz);
		}
		else
		{
			depth_in_fog= dot(_planar_fog_plane_coeffs, float4(pixel_position, 1.0f));
		}

		// if camera inside fog, let camera position determine thickness
		depth_in_fog= max(_camera_position_in_fog_depth, depth_in_fog);

		// soften fog need the boundary
		float extinction= compute_extinction(_planar_fog_thickness * saturate(depth_in_fog * _planar_fog_one_over_base_depth), depth_in_fog);
		float3 inscatter;
		float3 planar_fog_color= _planar_fog_color;

		[branch]
		if (k_bool_enable_color_palette)
		{
			float4 palette_color= sample2D(k_ps_planar_fog_sampler_palette, float2(1.0f - extinction, 0.5f));
			planar_fog_color= palette_color.rgb * _planar_fog_palette_color_intensity;
			if (k_bool_enable_alpha_palette) {
				extinction= palette_color.a;
			}
		}

		// calculate patchy fog effect
		[branch]
		if (k_bool_enable_patchy_effect)
		{
			IN.position_in_screen.xy/= IN.position_in_screen.w;

			float patchy_inscatter, patchy_optical_depth;
			evaluate_patchy_effect(
				IN.position_in_screen.xy,
				length(k_ps_eye_position - pixel_position),
				pixel_position,
				k_ps_texcoord_basis, k_ps_attenuation_data, k_ps_eye_position,
				k_ps_sheet_fade_factors0, k_ps_sheet_fade_factors1, k_ps_sheet_depths0, k_ps_sheet_depths1,
				k_ps_tex_coord_transform0, k_ps_tex_coord_transform1, k_ps_tex_coord_transform2, k_ps_tex_coord_transform3,
				k_ps_tex_coord_transform4, k_ps_tex_coord_transform5, k_ps_tex_coord_transform6, k_ps_tex_coord_transform7,

				k_ps_planar_fog_sampler_patchy_effect,
				_planar_fog_plane_coeffs,

				patchy_inscatter, patchy_optical_depth);

			inscatter= lerp( (1.0f - extinction) * planar_fog_color, patchy_inscatter * k_ps_patchy_effect_color.rgb, extinction);
			extinction*= 1.0f - patchy_inscatter;

		}
		else
		{
			inscatter= (1.0f - extinction) * planar_fog_color;
		}

		accum_pixel result;
		result.color.rgb= inscatter * BLEND_FOG_INSCATTER_SCALE*g_exposure.rrr;
		result.color.a= extinction;
	#ifdef xenon
		result.color.a *= 0.03125f;	// scale by 1/32
	#endif

		return result;
	}

	accum_pixel planar_fog_ps(
		in SCREEN_POSITION_INPUT(fragment_position_in_pixel),
		in s_fog_interpolators IN )
	{
		return calculate_planar_fog(fragment_position_in_pixel, IN, true);
	}

	accum_pixel planar_fog_full_screen_ps(
		in SCREEN_POSITION_INPUT(fragment_position_in_pixel),
		in s_fog_interpolators IN )
	{
		return calculate_planar_fog(fragment_position_in_pixel, IN, false);
	}

#endif //PIXEL_SHADER

#else /* implementation of pc version */

struct s_fog_interpolators
{
	float4 position	:SV_Position;
};

s_fog_interpolators planar_fog_vs()
{
	s_fog_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 planar_fog_ps(s_fog_interpolators INTERPOLATORS) :SV_Target0
{
	return float4(0,1,2,3);
}

s_fog_interpolators planar_fog_full_screen_vs()
{
	s_fog_interpolators OUT;
	OUT.position= 0.0f;
	return OUT;
}

float4 planar_fog_full_screen_ps(s_fog_interpolators INTERPOLATORS) :SV_Target0
{
	return float4(0,1,2,3);
}

#endif //pc/xenon

// end of rename marco
#undef planar_fog_vs
#undef planar_fog_ps
