
#define LDR_ONLY
//#define LDR_ALPHA_ADJUST	(1.0f / 32.0f)
#define LDR_gamma2			false

#include "shared\blend.fx"
#include "hlsl_constant_globals.fx"

#include "shared\texture_xform.fx"
#include "hlsl_vertex_types.fx"
#include "hlsl_entry_points.fx"
#include "shared\render_target.fx"
#include "effects\function_utilities.fx"


#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif

VERTEX_CONSTANT(float4,		screenspace_to_pixelspace_xform_vs,	c250);
VERTEX_CONSTANT(float4,		screenspace_xform_vs,				c251);

PIXEL_CONSTANT(float4,		screenspace_xform,					c200);
PIXEL_CONSTANT(float4,		inv_screenspace_xform,				c201);
PIXEL_CONSTANT(float4,		screenspace_to_pixelspace_xform,	c202);
PIXEL_CONSTANT(float4x4,	pixel_to_world_relative,			c204);

#undef LDR_gamma2


void default_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0)
{
	position.xy=	vertex.position;
	position.zw=	1.0f;
	texcoord.xy=	vertex.texcoord;
	texcoord.zw=	transform_texcoord(texcoord.xy,		screenspace_to_pixelspace_xform_vs);
}
void albedo_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float4 texcoord : TEXCOORD0)
{
	position.xy=	vertex.position;
	position.zw=	1.0f;
	texcoord.xy=	vertex.texcoord;
	texcoord.zw=	0.0f;					// will compute pixelspace in the pixel shader for screenshots
}


float2 get_screen_space(float4 texcoord)
{
#ifdef entry_point_albedo
	// screenshots
	return transform_texcoord(texcoord.xy, screenspace_xform);
#else
	// !screenshots
	return texcoord.xy;
#endif
}

float2 get_pixel_space(float4 texcoord)
{
#ifdef entry_point_albedo
	// screenshots
	float2 screenspace_texcoord=	get_screen_space(texcoord);
	return transform_texcoord(screenspace_texcoord, screenspace_to_pixelspace_xform);
#else
	// !screenshots
	return texcoord.zw;
#endif
}

float2 get_target_space(float4 texcoord)
{
#ifdef entry_point_albedo
	// screenshots
	return texcoord.xy;
#else
	// !screenshots
	return texcoord.xy;
#endif
}

float4 apply_warp(float4 texcoord, float2 warp)
{
#ifdef entry_point_albedo
	// screenshots
	texcoord.xy += warp * inv_screenspace_xform.xy;
#else
	// !screenshots
	texcoord.xy += warp;
#endif
	texcoord.zw += warp * screenspace_to_pixelspace_xform.xy;
	
	return texcoord;
}


#define CALC_WARP(type) calc_warp_##type

sampler2D	warp_map;
float4		warp_map_xform;
float		warp_amount;

float4 calc_warp_none(in float4 original_texcoord)
{
	return original_texcoord;
}

float4 calc_warp_pixel_space(in float4 original_texcoord)
{
	float2 warp= tex2D(warp_map,	transform_texcoord(get_pixel_space(original_texcoord), warp_map_xform)).xy;
	
	warp *= warp_amount;

	return apply_warp(original_texcoord, warp);
}

float4 calc_warp_screen_space(in float4 original_texcoord)
{
	float2 warp=	tex2D(warp_map,	transform_texcoord(get_screen_space(original_texcoord), warp_map_xform)).xy;

	warp *= warp_amount;

	return apply_warp(original_texcoord, warp);
}



#define CALC_BASE(type) calc_base_##type

sampler2D	base_map;
float4		base_map_xform;
sampler2D	detail_map;
float4		detail_map_xform;
sampler2D	normal_map;
float4		normal_map_xform;
sampler2D	stencil_map;
float4		stencil_map_xform;
sampler2D	palette;
float		palette_v;
float4		camera_forward;


float4 calc_base_single_screen_space(in float4 texcoord)
{
	float4	base=	tex2D(base_map,   transform_texcoord(get_screen_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_single_pixel_space(in float4 texcoord)
{
	float4	base=	tex2D(base_map,   transform_texcoord(get_pixel_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_single_target_space(in float4 texcoord)
{
	float4	base=	tex2D(base_map,   transform_texcoord(get_target_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_normal_map_edge_shade(in float4 texcoord)
{
	float4	world_relative=	mul(float4(texcoord.zw, 0.2f, 1.0f), transpose(pixel_to_world_relative));
	world_relative.xyz=	normalize(world_relative.xyz);
	
	float3	normal=			tex2D(normal_map,	transform_texcoord(texcoord.xy,	normal_map_xform)).rgb * 2.0 - 1.0;
	float2	palette_coord=	float2(-dot(normal, world_relative.xyz), palette_v);
	float4	base=			tex2D(palette, palette_coord);	
	
	return base;
}

float4 calc_base_normal_map_edge_stencil(in float4 texcoord)
{
	float4	world_relative=	mul(float4(texcoord.zw, 0.2f, 1.0f), transpose(pixel_to_world_relative));
	world_relative.xyz=	normalize(world_relative.xyz);
	
	float3	normal=			tex2D(normal_map,	transform_texcoord(texcoord.xy,	normal_map_xform)).rgb * 2.0 - 1.0;
	float2	palette_coord=	float2(-dot(normal, world_relative.xyz), palette_v);
	float4	base=			tex2D(palette, palette_coord);
	
	float	stencil=		tex2D(stencil_map,  transform_texcoord(texcoord.xy, stencil_map_xform)).b;
	base.a *= TEST_BIT(stencil * 255, 6);
	
	return base;
}

#define CALC_OVERLAY(type, stage) calc_overlay_##type(color, texcoord, detail_map_##stage, detail_map_##stage##_xform, detail_mask_##stage, detail_mask_##stage##_xform, detail_fade_##stage, detail_multiplier_##stage)

float4		tint_color;
float4		add_color;
float4		intensity_color_u;
float4		intensity_color_v;
sampler2D	detail_map_a;
float4		detail_map_a_xform;
sampler2D	detail_mask_a;
float4		detail_mask_a_xform;
float		detail_fade_a;
float		detail_multiplier_a;
sampler2D	detail_map_b;
float4		detail_map_b_xform;
sampler2D	detail_mask_b;
float4		detail_mask_b_xform;
float		detail_fade_b;
float		detail_multiplier_b;

float4 calc_overlay_none(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	return color;
}

float4 calc_overlay_tint_add_color(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	return color * tint_color + add_color;
}

float4 calc_overlay_detail_screen_space(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=	tex2D(detail_map, transform_texcoord(get_screen_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	detail=	lerp(1.0f, detail, detail_fade);
	return color * detail;
}

float4 calc_overlay_detail_pixel_space(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=	color * tex2D(detail_map, transform_texcoord(get_pixel_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	detail=	lerp(1.0f, detail, detail_fade);
	return color * detail;
}

float4 calc_overlay_detail_masked_screen_space(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=			tex2D(detail_map, transform_texcoord(get_screen_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	float4 detail_mask=		tex2D(detail_mask_map, transform_texcoord(get_screen_space(texcoord), detail_mask_map_xform));
	detail=	lerp(1.0f, detail, saturate(detail_fade*detail_mask.a));
	return color * detail;
}

float4 calc_overlay_palette_lookup(in float4 color, in float4 texcoord, sampler2D detail_map, in float4 detail_map_xform, sampler2D detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float3	vec=	color.rgb;
	float2 palette_coord=	float2(
								dot(vec.rgb, intensity_color_u.rgb),
								dot(vec.rgb, intensity_color_v.rgb));
	float4	detail=			tex2D(detail_map, palette_coord);
	color=	lerp(color, detail, detail_fade);
	return color;
}


float fade;

float4 calc_fade_out(in float4 color)
{
	float4 alpha_fade=	float4(fade, 1.0f - fade, 0.5f - 0.5f * fade, 0.0f);

#if BLEND_MODE(opaque)	
#elif BLEND_MODE(additive)
	color.rgba *=	alpha_fade.x;
#elif BLEND_MODE(multiply)
	color.rgba=		color.rgba * alpha_fade.x + alpha_fade.y;
#elif BLEND_MODE(alpha_blend)
	color.a *=		alpha_fade.x;
#elif BLEND_MODE(double_multiply)
	color.rgba=		color.rgba * alpha_fade.x + alpha_fade.z;
#elif BLEND_MODE(pre_multiplied_alpha)
	color.rgba	*=	alpha_fade.x;
	color.a		+=	alpha_fade.y;
#endif
	return color;
}


accum_pixel default_ps(
	in float4 original_texcoord : TEXCOORD0)
{
	float4 texcoord=	CALC_WARP(warp_type)(original_texcoord);

	float4 color=		CALC_BASE(base_type)(texcoord);
	color=				CALC_OVERLAY(overlay_a_type, a);
	color=				CALC_OVERLAY(overlay_b_type, b);
	
	color=				calc_fade_out(color);
		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(color, false, false);
}

accum_pixel albedo_ps(
	in float4 original_texcoord : TEXCOORD0)
{
	float4 texcoord=	CALC_WARP(warp_type)(original_texcoord);

	float4 color=		CALC_BASE(base_type)(texcoord);
	color=				CALC_OVERLAY(overlay_a_type, a);
	color=				CALC_OVERLAY(overlay_b_type, b);
	
	color=				calc_fade_out(color);
		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(color, false, false);
}
