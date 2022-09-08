
#define LDR_ONLY
//#define LDR_ALPHA_ADJUST	(1.0f / 32.0f)
#define LDR_gamma2			false

#include "hlsl_constant_globals.fx"
#include "shared\blend.fx"

#include "shared\texture_xform.fx"
#include "hlsl_vertex_types.fx"
#include "hlsl_entry_points.fx"
#include "shared\render_target.fx"
#include "effects\function_utilities.fx"
#include "effects\screen_registers.fx"


#undef LDR_gamma2


void default_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	out float4 texcoord : TEXCOORD0)
{
	position.xy=	vertex.position;
	position.zw=	1.0f;
	texcoord.xy=	vertex.texcoord;
	texcoord.zw=	transform_texcoord(texcoord.xy,		screenspace_to_pixelspace_xform_vs);
}

void albedo_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
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

PARAM_SAMPLER_2D(warp_map);
PARAM(float4, warp_map_xform);
PARAM(float, warp_amount);

float4 calc_warp_none(in float4 original_texcoord)
{
	return original_texcoord;
}

float4 calc_warp_pixel_space(in float4 original_texcoord)
{
	float2 warp= sample2D(warp_map,	transform_texcoord(get_pixel_space(original_texcoord), warp_map_xform)).xy;

	warp *= warp_amount;

	return apply_warp(original_texcoord, warp);
}

float4 calc_warp_screen_space(in float4 original_texcoord)
{
	float2 warp=	sample2D(warp_map,	transform_texcoord(get_screen_space(original_texcoord), warp_map_xform)).xy;

	warp *= warp_amount;

	return apply_warp(original_texcoord, warp);
}



#define CALC_BASE(type) calc_base_##type

PARAM_SAMPLER_2D(base_map);
PARAM(float4, base_map_xform);
PARAM_SAMPLER_2D(detail_map);
PARAM(float4, detail_map_xform);
PARAM_SAMPLER_2D(normal_map);
PARAM(float4, normal_map_xform);
PARAM_SAMPLER_2D_TYPED(stencil_map, uint2);
PARAM(float4, stencil_map_xform);
PARAM_SAMPLER_2D(palette);
PARAM(float, palette_v);
PARAM(float4, camera_forward);


float4 calc_base_single_screen_space(in float4 texcoord)
{
	float4	base=	sample2D(base_map,   transform_texcoord(get_screen_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_single_pixel_space(in float4 texcoord)
{
	float4	base=	sample2D(base_map,   transform_texcoord(get_pixel_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_single_target_space(in float4 texcoord)
{
	float4	base=	sample2D(base_map,   transform_texcoord(get_target_space(texcoord), base_map_xform));
	return	base;
}

float4 calc_base_normal_map_edge_shade(in float4 texcoord)
{
	float4	world_relative=	mul(float4(texcoord.zw, 0.2f, 1.0f), transpose(pixel_to_world_relative));
	world_relative.xyz=	normalize(world_relative.xyz);

	float3	normal=			sample2D(normal_map,	transform_texcoord(texcoord.xy,	normal_map_xform)).rgb * 2.0 - 1.0;
	float2	palette_coord=	float2(-dot(normal, world_relative.xyz), palette_v);
	float4	base=			sample2D(palette, palette_coord);

	return base;
}

float4 calc_base_normal_map_edge_stencil(in float4 texcoord)
{
	float4	world_relative=	mul(float4(texcoord.zw, 0.2f, 1.0f), transpose(pixel_to_world_relative));
	world_relative.xyz=	normalize(world_relative.xyz);

	float3	normal=			sample2D(normal_map,	transform_texcoord(texcoord.xy,	normal_map_xform)).rgb * 2.0 - 1.0;
	float2	palette_coord=	float2(-dot(normal, world_relative.xyz), palette_v);
	float4	base=			sample2D(palette, palette_coord);

#if DX_VERSION == 9
	float	stencil=		sample2D(stencil_map,  transform_texcoord(texcoord.xy, stencil_map_xform)).b;
	base.a *= TEST_BIT(stencil * 255, 6);
#else
	float2 uv = transform_texcoord(texcoord.xy, stencil_map_xform);

	uint2 dim;
	stencil_map.t.GetDimensions(dim.x, dim.y);

	uint2 coord = uint2(uv * dim);

#ifdef durango
	// G8 SRVs are broken on Durango - components are swapped
	uint stencil= stencil_map.t.Load(uint3(coord, 0)).r;
#else
	uint stencil= stencil_map.t.Load(uint3(coord, 0)).g;
#endif
	base.a *= ((stencil >> 6) & 1);
#endif

	return base;
}

#define CALC_OVERLAY(type, stage) calc_overlay_##type(color, texcoord, detail_map_##stage, detail_map_##stage##_xform, detail_mask_##stage, detail_mask_##stage##_xform, detail_fade_##stage, detail_multiplier_##stage)

PARAM(float4, tint_color);
PARAM(float4, add_color);
PARAM(float4, intensity_color_u);
PARAM(float4, intensity_color_v);
PARAM_SAMPLER_2D(detail_map_a);
PARAM(float4, detail_map_a_xform);
PARAM_SAMPLER_2D(detail_mask_a);
PARAM(float4, detail_mask_a_xform);
PARAM(float, detail_fade_a);
PARAM(float, detail_multiplier_a);
PARAM_SAMPLER_2D(detail_map_b);
PARAM(float4, detail_map_b_xform);
PARAM_SAMPLER_2D(detail_mask_b);
PARAM(float4, detail_mask_b_xform);
PARAM(float, detail_fade_b);
PARAM(float, detail_multiplier_b);

float4 calc_overlay_none(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	return color;
}

float4 calc_overlay_tint_add_color(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	return color * tint_color + add_color;
}

float4 calc_overlay_detail_screen_space(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=	sample2D(detail_map, transform_texcoord(get_screen_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	detail=	lerp(1.0f, detail, detail_fade);
	return color * detail;
}

float4 calc_overlay_detail_pixel_space(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=	color * sample2D(detail_map, transform_texcoord(get_pixel_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	detail=	lerp(1.0f, detail, detail_fade);
	return color * detail;
}

float4 calc_overlay_detail_masked_screen_space(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float4 detail=			sample2D(detail_map, transform_texcoord(get_screen_space(texcoord), detail_map_xform));
	detail.rgb *= detail_multiplier;
	float4 detail_mask=		sample2D(detail_mask_map, transform_texcoord(get_screen_space(texcoord), detail_mask_map_xform));
	detail=	lerp(1.0f, detail, saturate(detail_fade*detail_mask.a));
	return color * detail;
}

float4 calc_overlay_palette_lookup(in float4 color, in float4 texcoord, texture_sampler_2d detail_map, in float4 detail_map_xform, texture_sampler_2d detail_mask_map, in float4 detail_mask_map_xform, in float detail_fade, in float detail_multiplier)
{
	float3	vec=	color.rgb;
	float2 palette_coord=	float2(
								dot(vec.rgb, intensity_color_u.rgb),
								dot(vec.rgb, intensity_color_v.rgb));
	float4	detail=			sample2D(detail_map, palette_coord);
	color=	lerp(color, detail, detail_fade);
	return color;
}


PARAM(float, fade);

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
	SCREEN_POSITION_INPUT(screen_pos),
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
	SCREEN_POSITION_INPUT(screen_pos),
	in float4 original_texcoord : TEXCOORD0)
{
	float4 texcoord=	CALC_WARP(warp_type)(original_texcoord);

	float4 color=		CALC_BASE(base_type)(texcoord);
	color=				CALC_OVERLAY(overlay_a_type, a);
	color=				CALC_OVERLAY(overlay_b_type, b);

	color=				calc_fade_out(color);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(color, false, false);
}
