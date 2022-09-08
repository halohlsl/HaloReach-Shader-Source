/*
CONTRAIL_RENDER.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/14/2005 4:14:31 PM (davcook)

Shaders for contrail renders, strip manufacture
*/

#undef MEMEXPORT_ENABLED

// Allow legacy dynamic shader to compile, during transition
#ifndef CONTRAIL_RENDER_METHOD_DEFINITION
#define TEST_CATEGORY_OPTION(cat, opt) true
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))
#endif

#include "hlsl_constant_globals.fx"
#include "shared\blend.fx"


#include "hlsl_vertex_types.fx"
#include "effects\contrail_render_registers.fx"	// must come before contrail_common.fx
#include "effects\function_utilities.fx"

#ifdef VERTEX_SHADER
#include "effects\contrail_registers.fx"
#include "effects\contrail_profile.fx"
#include "shared\atmosphere.fx"
#endif

#define BLEND_MODE_SELF_ILLUM (TEST_CATEGORY_OPTION(blend_mode, additive) || TEST_CATEGORY_OPTION(blend_mode, add_src_times_srcalpha))

//This comment causes the shader compiler to be invoked for certain types
//@generate contrail

// The following defines the protocol for passing interpolated data between the vertex shader
// and the pixel shader.  It pays to compress the data into as few interpolators as possible.
// The reads and writes should evaporate out of the compiled code into the register mapping.
struct s_contrail_render_vertex
{
    float4 m_position;
    float2 m_texcoord;
    float m_black_point; // avoid using interpolator for constant-per-profile value?
    float m_palette;	// avoid using interpolator for constant-per-profile value?
    float4 m_color;		// COLOR semantic will not clamp to [0,1].
    float3 m_color_add;		// COLOR semantic will not clamp to [0,1].
};

struct s_contrail_interpolators
{
	float4 m_position0	:SV_Position;
	float4 m_color0		:COLOR0;
	float4 m_color1		:COLOR1;
	float4 m_texcoord0	:TEXCOORD0;
};

s_contrail_interpolators write_contrail_interpolators(s_contrail_render_vertex VERTEX)
{
	s_contrail_interpolators INTERPOLATORS;

	INTERPOLATORS.m_position0= VERTEX.m_position;
	INTERPOLATORS.m_color0= VERTEX.m_color;
	INTERPOLATORS.m_color1= float4(VERTEX.m_color_add, VERTEX.m_black_point);
	INTERPOLATORS.m_texcoord0= float4(VERTEX.m_texcoord, VERTEX.m_palette, 0.0f);

	return INTERPOLATORS;
}

s_contrail_render_vertex read_contrail_interpolators(s_contrail_interpolators INTERPOLATORS)
{
	s_contrail_render_vertex VERTEX;

	VERTEX.m_position= INTERPOLATORS.m_position0;
	VERTEX.m_color= INTERPOLATORS.m_color0;
	VERTEX.m_color_add= INTERPOLATORS.m_color1;
	VERTEX.m_black_point= INTERPOLATORS.m_color1.w;
	VERTEX.m_texcoord= INTERPOLATORS.m_texcoord0.xy;
	VERTEX.m_palette= INTERPOLATORS.m_texcoord0.z;

	return VERTEX;
}

#ifdef VERTEX_SHADER
#if !defined(pc) || (DX_VERSION == 11)

// Match with c_contrail_definition::e_profile
#define _profile_ribbon		0
#define _profile_cross		1
#define _profile_ngon		2
#define _profile_type_max	3

#include "effects\contrail_strip.fx"

#if DX_VERSION == 9
PARAM_STRUCT(s_strip, g_strip);
#endif

// Take the index from the vertex input semantic and translate it into the actual lookup
// index in the vertex buffer.
int profile_index_to_buffer_index( int profile_index )
{
	int beam_row= round(profile_index / k_profiles_per_row);
	int profile_index_within_row= floor((profile_index + 0.5) % k_profiles_per_row);
	int buffer_row= g_strip.m_row[beam_row];

	return buffer_row * k_profiles_per_row + profile_index_within_row;
}

#if DX_VERSION == 9
// Take the index from the vertex input semantic and translate it into strip, index, and offset.
void calc_strip_profile_and_offset( in int index, out int strip_index, out int buffer_index, out int offset )
{
	float verts_per_strip= g_all_state.m_num_profiles * 2;
	strip_index= floor((index + 0.5f) / verts_per_strip);
	float index_within_strip= index - strip_index * verts_per_strip;
	buffer_index= floor((index_within_strip + 0.5f) / 2);
	offset= index_within_strip - buffer_index * 2;
}
#endif

float2 strip_and_offset_to_cross_sectional_offset( int strip_index, int offset )
{
	if (g_all_state.m_profile_type== _profile_ribbon || g_all_state.m_profile_type== _profile_cross)
	{
		static float2x2 shift[2]= {{{-0.5f, 0.0f}, {0.5f, 0.0f}, }, {{0.0f, -0.5f}, {0.0f, 0.5f}, }, };
		return shift[strip_index][offset];
   }
   else //if (g_all_state.m_profile_type== _profile_ngon)
   {
		float radians= _2pi * (strip_index + offset) / g_all_state.m_ngon_sides;
		return 0.5f * float2(cos(radians), -sin(radians));	// the '-' causes inward-facing sides to be backface-culled.
	}
}

float2 profile_offset_to_texcoord( int strip_index, int offset, float cumulative_length )
{
	float v_shift; // number from -0.5f to 0.5f ranging across/around the cross-section
	if (g_all_state.m_profile_type== _profile_ribbon || g_all_state.m_profile_type== _profile_cross)
	{
		v_shift= offset - 0.5f;
	}
	else //if (g_all_state.m_profile_type== _profile_ngon)
	{
		v_shift= (strip_index + offset) / g_all_state.m_ngon_sides - 0.5f;
	}
	return float2(cumulative_length, v_shift)*g_all_state.m_uv_tiling_rate
		+float2(0.0f, 0.5f)
		+g_all_state.m_game_time*g_all_state.m_uv_scroll_rate
		+g_all_state.m_uv_offset;
}

// Calculation the direction of the beam at the profile by sampling the position of
// a neighboring profile.

float3 profile_direction(int profile_index, float3 position)
{
	bool off_the_end= (profile_index>= g_all_state.m_num_profiles - 1);
	int next_profile_index= profile_index + (off_the_end ? -1 : 1);
	s_profile_state STATE= read_profile_state(profile_index_to_buffer_index(next_profile_index));

	return (off_the_end ? -1.0f : 1.0f) * (STATE.m_position - position);
}

// Plane perpendicular to beam with basis[0] horizontal in world space.
float2x3 cross_section_world_basis (float3 direction)
{
	float2x3 basis;

	static float3 up= {0.0f, 0.0f, 1.0f};
	basis[0]= normalize(cross(direction, up));
	basis[1]= normalize(cross(basis[0], direction));

	return basis;
}

// Plane perpendicular to beam with basis[0] parallel to screen.
float2x3 cross_section_billboard_basis (float3 position, float3 direction)
{
	float2x3 basis;

	basis[0]= normalize(cross(position - Camera_Position, direction));
	basis[1]= normalize(cross(basis[0], direction));

	return basis;
}
#endif	//#ifndef pc

// Actual input vertex format is hard-coded in vfetches as s_profile_state
s_contrail_interpolators default_vs(
#if DX_VERSION == 11
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID
#else
	vertex_type vIN
#endif
)
{
	s_contrail_render_vertex OUT;
#if !defined(pc) || (DX_VERSION == 11)
	// This would be used for killing verts by setting oPts.z!=0 .
	//asm {
	//	config VsExportMode=kill
	//};

	// Break the input index into a strip index, a profile index and an {0,1}-offset.
	int strip_index, profile_index, offset;
#if DX_VERSION == 11
	strip_index = instance_id;
	profile_index = vertex_id / 2;
	offset = vertex_id & 1;
	s_profile_state STATE= read_profile_state(profile_index_to_buffer_index(profile_index));
#else
	calc_strip_profile_and_offset(IN.index, strip_index, profile_index, offset);
	s_profile_state STATE= read_profile_state(profile_index_to_buffer_index(profile_index));
#endif

	// We compute and store all these in the update for now.
	//float pre_evaluated_scalar[_index_max]= preevaluate_profile_functions(STATE, preevaluate_mask);

	// Kill timed-out profiles...
	// Should be using oPts.z kill, but that's hard to do in hlsl.
	// XDS says equivalent to set position to NaN?
	if (STATE.m_age >= 1.0f)
	{
#if DX_VERSION == 11
		OUT.m_position = 0;
#else
		OUT.m_position = hidden_from_compiler.xxxx;	// NaN
#endif

		OUT.m_texcoord = float2(0.0f, 0.0f);
		OUT.m_black_point = 0.0f;
		OUT.m_palette = 0.0f;
		OUT.m_color= float4(0.0f, 0.0f, 0.0f, 0.0f);
		OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
	}
	else
	{
		// Compute the direction by sampling the position of the next profile (!)
		float3 direction = profile_direction(profile_index, STATE.m_position);

		// Compute the vertex position within the cross-sectional plane of the profile
		float2 cross_section_pos = strip_and_offset_to_cross_sectional_offset(strip_index, offset) * STATE.m_size;

		// Transform from cross-section plane to world space.
		float2x3 world_basis= cross_section_world_basis(direction);
		float2x3 billboard_basis= (g_all_state.m_profile_type== _profile_ribbon) ? cross_section_billboard_basis(STATE.m_position, direction) : world_basis;
		float rotation= STATE.m_rotation;
		float rotsin, rotcos;
		sincos(_2pi*rotation, rotsin, rotcos);
		float2x2 rotmat= {{rotcos, rotsin}, {-rotsin, rotcos}, };
		billboard_basis= mul(rotmat, billboard_basis);

		float3 world_pos = STATE.m_position + mul(cross_section_pos, billboard_basis) + mul(STATE.m_offset, world_basis);

		// Transform from world space to clip space.
		OUT.m_position= mul(float4(world_pos, 1.0f), View_Projection);

		// Compute vertex texcoord
		OUT.m_texcoord= profile_offset_to_texcoord(strip_index, offset, STATE.m_length);

		// Compute profile color
		OUT.m_color= STATE.m_color * STATE.m_intensity;
		OUT.m_color.xyz*= STATE.m_initial_color.xyz * exp2(STATE.m_initial_color.w);
		OUT.m_color.w*= STATE.m_initial_alpha;
		IF_CATEGORY_OPTION(blend_mode, multiply)
		{
		}
		else if (BLEND_MODE_SELF_ILLUM)
		{
			OUT.m_color.xyz*= V_ILLUM_EXPOSURE;
		}
		else
		{
			OUT.m_color.xyz*= v_exposure.x;
		}
		IF_CATEGORY_OPTION(fog, on)	// fog
		{
			float3 inscatter;
			float extinction;
			compute_scattering(Camera_Position, world_pos.xyz, inscatter, extinction);
			OUT.m_color.xyz*= extinction;
			OUT.m_color_add.xyz= inscatter * v_exposure.x;
		}
		else
		{
			OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
		}
		if (TEST_BIT(g_all_state.m_appearance_flags,_contrail_origin_faded_bit))
		{
			OUT.m_color.w*= saturate(g_all_state.m_origin_range *
				(STATE.m_length - g_all_state.m_origin_cutoff));
		}
		if (TEST_BIT(g_all_state.m_appearance_flags,_contrail_edge_faded_bit))
		{
			// Fade to transparent when profile plane is parallel to screen plane
			float3 profile_normal= normalize(cross(billboard_basis[0], billboard_basis[1]));
			float profile_angle= acos(abs(dot(-Camera_Backward, profile_normal)));
			OUT.m_color.w*= saturate(g_all_state.m_edge_range * (profile_angle - g_all_state.m_edge_cutoff));
		}

		// Compute profile black point
		OUT.m_black_point= STATE.m_black_point;
		OUT.m_palette= STATE.m_palette;
	}
#else	//#ifndef pc
	OUT.m_position= float4(0.0f, 0.0f, 0.0f, 0.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
	OUT.m_color= float4(0.0f, 0.0f, 0.0f, 0.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
	OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
	OUT.m_texcoord = float2(0.0f, 0.0f);
	OUT.m_black_point = 0.0f;
	OUT.m_palette = 0.0f;
#endif	//#ifndef pc #else

	return write_contrail_interpolators(OUT);
}
#endif	//#ifdef VERTEX_SHADER

#ifdef PIXEL_SHADER
// Specialized routine for smoothly fading out profiles.  Maps
//		[0, black_point] to 0
//		[black_point, mid_point] to [0, mid_point] linearly
//		[mid_point, 1] to [mid_point, 1] by identity
// where mid_point is halfway between black_point and 1
//
//		|                   **
//		|                 **
//		|               **
//		|             **
//		|            *
//		|           *
//		|          *
//		|         *
//		|        *
//		|       *
//		|*******_____________
//      0      bp    mp      1
float remap_alpha(float black_point, float alpha)
{
	float mid_point= (black_point+1.0f)/2.0f;
	return mid_point*saturate((alpha-black_point)/(mid_point-black_point))
		+ saturate(alpha-mid_point);	// faster than a branch
}


#include "shared\utilities.fx"
#include "shared\render_target.fx"

PARAM_SAMPLER_2D(base_map);
PARAM_SAMPLER_2D(palette);
PARAM_SAMPLER_2D(alpha_map);

float4 sample_diffuse(float2 texcoord, float palette_v)
{
	IF_CATEGORY_OPTION(albedo, diffuse_only)
	{
		return sample2D(base_map, texcoord);
	}

	// Dependent texture fetch.  The palette can be any size.  In order to avoid filtering artifacts,
	// the palette should be smoothly varying, or else filtering should be turned off.
	IF_CATEGORY_OPTION(albedo, palettized)
	{
		float index= sample2D(base_map, texcoord).x;
		return sample2D(palette, float2(index, palette_v));
	}

	// Same as above except the alpha comes from the original texture, not the palette.
	IF_CATEGORY_OPTION(albedo, palettized_plus_alpha)
	{
		float index= sample2D(base_map, texcoord).x;
		float alpha= sample2D(alpha_map, texcoord).w;
		return float4(sample2D(palette, float2(index, palette_v)).xyz, alpha);
	}
}

typedef accum_pixel s_contrail_render_pixel_out;
s_contrail_render_pixel_out default_ps(s_contrail_interpolators INTERPOLATORS)
{
#if !defined(pc) || (DX_VERSION == 11)
	s_contrail_render_vertex IN= read_contrail_interpolators(INTERPOLATORS);

	float4 blended= sample_diffuse(IN.m_texcoord, IN.m_palette);

	IF_CATEGORY_OPTION(black_point, on)
	{
		blended.w= remap_alpha(IN.m_black_point, blended.w);
	}

	blended*= IN.m_color;

	// Non-linear blend modes don't work under the normal framework...
	IF_CATEGORY_OPTION(blend_mode, multiply)
	{
		blended.xyz= lerp(float3(1.0f, 1.0f, 1.0f), blended.xyz, blended.w);
	}
	else
	{
		blended.xyz+= IN.m_color_add;
	}
#else
	float4 blended= float4(0.0f, 0.0f, 0.0f, 0.0f);
#endif
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(blended, false, false);
}
#endif	//#ifdef PIXEL_SHADER
