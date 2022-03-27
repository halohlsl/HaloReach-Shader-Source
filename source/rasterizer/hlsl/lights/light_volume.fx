/*
LIGHT_VOLUME.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/14/2005 4:14:31 PM (davcook)
	
Shaders for light_volume renders
*/

#undef MEMEXPORT_ENABLED

// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
// We could automatically prepend this to the shader file when doing generate-templates, hmmm...
#ifndef category_blend_mode
extern int category_blend_mode;
#endif
#ifndef category_fog
extern int category_fog;
#endif

#include "shared\blend.fx"

#ifndef PIXEL_SHADER

// vertex shader needs to handle all cases including transparent:
#define SCOPE_TRANSPARENTS

#endif

#include "hlsl_constant_globals.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);

#include "hlsl_vertex_types.fx"

#ifdef VERTEX_SHADER
#include "effects\light_volume_common.fx"
#include "shared\atmosphere.fx"
#endif

extern float depth_fade_bias : register(c8);

//This comment causes the shader compiler to be invoked for certain types
//@generate s_light_volume_vertex

// The following defines the protocol for passing interpolated data between the vertex shader 
// and the pixel shader.  It pays to compress the data into as few interpolators as possible.
// The reads and writes should evaporate out of the compiled code into the register mapping.
struct s_light_volume_render_vertex
{
    float4	m_position;
    float2	m_texcoord;
    float2	m_screencoord;
    float4	m_color;			// scale rgba
    float	m_depth;
};

struct s_light_volume_interpolators
{
	float4	m_position0	:POSITION0;
	float4	m_color0	:COLOR0;
	float4	m_texcoord0	:TEXCOORD0;		// texcoord, screencoord
};

s_light_volume_interpolators write_light_volume_interpolators(s_light_volume_render_vertex VERTEX)
{
	s_light_volume_interpolators INTERPOLATORS;
	
//	if (VERTEX.m_position.w > 0.0f)
//	{
		VERTEX.m_position.xyzw /= abs(VERTEX.m_position.w);					// turn off perspective correction
//	}
	
	INTERPOLATORS.m_position0=	VERTEX.m_position.xyzw;
	INTERPOLATORS.m_color0=		float4(VERTEX.m_color.rgb * VERTEX.m_color.w, VERTEX.m_depth);
	INTERPOLATORS.m_texcoord0=	float4(VERTEX.m_texcoord, VERTEX.m_screencoord);

	return INTERPOLATORS;
}

s_light_volume_render_vertex read_light_volume_interpolators(s_light_volume_interpolators INTERPOLATORS)
{
	s_light_volume_render_vertex VERTEX;
	
	VERTEX.m_position=		INTERPOLATORS.m_position0;
	VERTEX.m_color.rgb=		INTERPOLATORS.m_color0;
	VERTEX.m_color.w=		1.0f;
	VERTEX.m_depth=			INTERPOLATORS.m_color0.w;
	VERTEX.m_texcoord=		INTERPOLATORS.m_texcoord0.xy;
	VERTEX.m_screencoord=	INTERPOLATORS.m_texcoord0.zw;	// * INTERPOLATORS.m_color0.w;

	return VERTEX;
}

#ifdef VERTEX_SHADER
	
// Actual input vertex format is hard-coded in vfetches as s_profile_state
s_light_volume_interpolators default_vs( vertex_type IN )
{
	s_light_volume_render_vertex OUT;
#ifndef pc
	// This would be used for killing verts by setting oPts.z!=0 .
	//asm {
	//	config VsExportMode=kill
	//};
	
	s_profile_state STATE;
	float2 coords;
	
#if IS_VERTEX_TYPE(s_light_volume_pre_vertex)
	// precompiled vertex
	int profile_index=	floor(IN.index * 0.25f + 0.125f);
    float4 color_thickness;
    asm
    {
        vfetch color_thickness, profile_index, texcoord0;
    };
	
	STATE.m_percentile=		profile_index / (g_all_state.m_num_profiles-1);
	STATE.m_position=		g_all_state.m_origin + g_all_state.m_direction * (g_all_state.m_offset + g_all_state.m_profile_distance * profile_index);
	STATE.m_color.rgb=		color_thickness.rgb;
	STATE.m_color.a=		1.0f;
	STATE.m_thickness=		color_thickness.a;
	STATE.m_intensity=		1.0f;
	
	float4x2 shift = {{0.0f, 0.0f}, {1.0f, 0.0f}, {1.0f, 1.0f}, {0.0f, 1.0f}, };
	coords=	shift[round(IN.index % 4)];
#else
	// Break the input index into a prim index and a vert index within the primitive.
	int2 index_and_offset=	int2(round(IN.index / 4), round(IN.index % 4));
	int profile_index=		index_and_offset.x;
	index_and_offset.x=		profile_index_to_buffer_index(index_and_offset.x);
	STATE= read_profile_state(index_and_offset.x);

	// ###ctchou: NOTE we are recalculating the percentile and position, instead of fetching it.   It's faster and we don't have to rebuild our profile buffer just to move the darn thing
	STATE.m_percentile=		profile_index / (g_all_state.m_num_profiles-1);
	STATE.m_position=		g_all_state.m_origin + g_all_state.m_direction * (g_all_state.m_offset + g_all_state.m_profile_distance * profile_index);
	
	float4x2 shift = {{0.0f, 0.0f}, {1.0f, 0.0f}, {1.0f, 1.0f}, {0.0f, 1.0f}, };
	coords=	shift[index_and_offset.y];
#endif
	
	// Compute some useful quantities
	float3 camera_to_profile= normalize(STATE.m_position - Camera_Position);
	float sin_view_angle= length(cross(g_all_state.m_direction, normalize(camera_to_profile)));
	
	// Profiles have aspect ratio 1 from head-on, but not from the side
	float profile_length=	lerp(STATE.m_thickness, g_all_state.m_profile_length, sin_view_angle);
//	float profile_aspect=	lerp(1.0f,	g_all_state.m_profile_length,	sin_view_angle);
//	float profile_length=	STATE.m_thickness * profile_aspect;
	
	// Compute the vertex position within the plane of the sprite
	float2 billboard_pos= (coords * 1.0f - 0.5f) * float2(profile_length, STATE.m_thickness);
	
	// Transform from profile space to world space. 
	// Basis is facing camera, but rotated based on light volume direction
	float2x3 billboard_basis;
	billboard_basis[1]= normalize(cross(camera_to_profile, g_all_state.m_direction));
	billboard_basis[0]= cross(camera_to_profile, billboard_basis[1]);
	float3 world_pos= STATE.m_position + mul(billboard_pos, billboard_basis);

	IF_CATEGORY_OPTION(depth_fade, biased)
	{	
		float3 position_to_camera= normalize(Camera_Position - world_pos);
		world_pos += position_to_camera * depth_fade_bias;
	}
	
	// Transform from world space to clip space. 
	OUT.m_position= mul(float4(world_pos, 1.0f), View_Projection);
	
	// Compute vertex texcoord
	OUT.m_texcoord= coords;

	// Compute profile color
	OUT.m_color= STATE.m_color * STATE.m_intensity;
	IF_NOT_CATEGORY_OPTION(blend_mode, multiply)
	{
		OUT.m_color.xyz*= V_ILLUM_EXPOSURE;
	}
	IF_CATEGORY_OPTION(fog, on)	// fog
	{
		float3 inscatter;
		float extinction;
		compute_scattering(Camera_Position, STATE.m_position, inscatter, extinction);
		OUT.m_color.xyz*= extinction;
//		OUT.m_color_add.xyz= inscatter * v_exposure.x;
	}
	else
	{
//		OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
	}
	
	// Total intensity at a pixel should be approximately the same from all angles and any profile density.
	// Reduce alpha by the expected overdraw factor.
	float spacing= g_all_state.m_profile_distance * sin_view_angle;
	float overdraw= min(g_all_state.m_num_profiles, profile_length / spacing);
	OUT.m_color.w*= lerp(g_all_state.m_brightness_ratio, 1.0f, sin_view_angle) / overdraw;
	
	float depth= dot(Camera_Backward, Camera_Position-world_pos.xyz);
	OUT.m_depth= depth;
	
	OUT.m_screencoord=	(OUT.m_position.xy / OUT.m_position.w) * float2(0.5, -0.5) + float2(0.5, 0.5);
	
#else	//#ifndef pc
	OUT.m_position= float4(0.0f, 0.0f, 0.0f, 1.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
	OUT.m_color= float4(0.0f, 0.0f, 0.0f, 0.0f);	// Doesn't work on PC!!!  (This just makes it compile.)
//	OUT.m_color_add= float3(0.0f, 0.0f, 0.0f);
	OUT.m_depth=	0.0f;
	OUT.m_texcoord = float2(0.0f, 0.0f);
	OUT.m_screencoord=	float2(0.0f, 0.0f);
#endif	//#ifndef pc

    return write_light_volume_interpolators(OUT);
}
#endif	//#ifdef VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "shared\utilities.fx"
#include "shared\render_target.fx"

extern sampler base_map;

extern float depth_fade_range : register(c80);

extern float center_offset;
extern float falloff;


float4 sample_diffuse(float2 texcoord)
{
	IF_CATEGORY_OPTION(albedo, circular)
	{
		float2	delta=		2 * texcoord - 1;
		float	radius=		saturate(center_offset - center_offset * dot(delta.xy, delta.xy));
//		float	alpha=		radius * radius * sqrt(radius);
		float	alpha=		pow(radius, falloff);
		return	float4(alpha, alpha, alpha, 1.0f);
	}
	IF_CATEGORY_OPTION(albedo, diffuse_only)
	{
		return tex2D(base_map, texcoord);
	}
}

float compute_depth_fade(float2 screen_coords, float depth, float range)
{
#ifndef pc
	if (!TEST_CATEGORY_OPTION(depth_fade, off) && !TEST_CATEGORY_OPTION(blend_mode, opaque))
	{	
		float4 depth_value;
		asm 
		{
			tfetch2D depth_value, screen_coords, depth_buffer, UnnormalizedTextureCoords = false, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
		};
		float scene_depth= 1.0f - depth_value.x;
		scene_depth= 1.0f / (depth_constants.x + scene_depth * depth_constants.y);	// convert to real depth
		float particle_depth= depth;
		float delta_depth= scene_depth - particle_depth;
		return saturate(delta_depth / range);
	}
	else
#endif // !pc	
	{
		return 1.0f;
	}
}

typedef accum_pixel s_light_volume_render_pixel_out;
s_light_volume_render_pixel_out default_ps(s_light_volume_interpolators INTERPOLATORS)
{
#ifndef pc
	s_light_volume_render_vertex IN= read_light_volume_interpolators(INTERPOLATORS);

	float depth_fade=	compute_depth_fade(IN.m_screencoord, IN.m_depth, depth_fade_range);

	float4 blended=		sample_diffuse(IN.m_texcoord);

	blended.w *=		depth_fade;
	
	blended *=			IN.m_color;
	
	// Non-linear blend modes don't work under the normal framework...
	IF_CATEGORY_OPTION(blend_mode, multiply)
	{
		blended.xyz= lerp(float3(1.0f, 1.0f, 1.0f), blended.xyz, blended.w);
	}
	else
	{
		blended.xyz *=	blended.w;
		blended.w=		1.0f;
//		blended.xyz += IN.m_color_add;
	}
#else
	float4 blended= float4(0.0f, 0.0f, 0.0f, 0.0f);
#endif
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(blended, false, false);
}
#endif	//#ifdef PIXEL_SHADER
