#ifndef _ALBEDO_FX_
#define _ALBEDO_FX_


#include "templated\pc_lighting.fx"

#define DETAIL_MULTIPLIER 4.59479f
// 4.59479f == 2 ^ 2.2  (sRGB gamma)

#define ALBEDO_TYPE(albedo_option) ALBEDO_TYPE_##albedo_option

#define ALBEDO_TYPE_calc_albedo_default_ps										101
#define ALBEDO_TYPE_calc_albedo_detail_blend_ps									102
#define ALBEDO_TYPE_calc_albedo_constant_color_ps								103
#define ALBEDO_TYPE_calc_albedo_two_change_color_ps								104
#define ALBEDO_TYPE_calc_albedo_four_change_color_ps							105
#define ALBEDO_TYPE_calc_albedo_three_detail_blend_ps							106
#define ALBEDO_TYPE_calc_albedo_two_detail_overlay_ps							107
#define ALBEDO_TYPE_calc_albedo_two_detail_ps									108
#define ALBEDO_TYPE_calc_albedo_color_mask_ps									109
#define ALBEDO_TYPE_calc_albedo_two_detail_black_point_ps						110
#define ALBEDO_TYPE_calc_albedo_four_change_color_applying_to_specular_ps		111
#define ALBEDO_TYPE_calc_albedo_simple_ps										112
#define ALBEDO_TYPE_calc_albedo_base_ps											113
#define ALBEDO_TYPE_calc_albedo_detail_ps										114


#ifndef SAMPLE_ALBEDO_TEXTURE
#define SAMPLE_ALBEDO_TEXTURE tex2D
#endif

float blend_alpha;
float4 albedo_color;
float4 albedo_color2;		// used for color-mask
float4 albedo_color3;

sampler base_map;
float4 base_map_xform;
sampler detail_map;
float4 detail_map_xform;
sampler camouflage_change_color_map;
float4 camouflage_change_color_map_xform;
float camouflage_scale;

void calc_albedo_constant_color_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	albedo= albedo_color;
	
	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_simple_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=	SAMPLE_ALBEDO_TEXTURE(base_map,   transform_texcoord(texcoord, base_map_xform));
	albedo.rgba= base.rgba * albedo_color.rgba;
	
	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_base_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	albedo=	SAMPLE_ALBEDO_TEXTURE(base_map,   transform_texcoord(texcoord, base_map_xform));

	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_detail_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
#ifndef pc
	[isolate]
#endif
	float4	base=	SAMPLE_ALBEDO_TEXTURE(base_map,   transform_texcoord(texcoord, base_map_xform));
	float4	detail=	SAMPLE_ALBEDO_TEXTURE(detail_map, transform_texcoord(texcoord, detail_map_xform));

	albedo.rgb= base.rgb * (detail.rgb * DETAIL_MULTIPLIER);
	albedo.w= base.w*detail.w;

	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_default_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=	SAMPLE_ALBEDO_TEXTURE(base_map,   transform_texcoord(texcoord, base_map_xform));
/*
	// ###ctchou $TODO this is a test for the mip bias workaround...
	float2	coord=	transform_texcoord(texcoord, base_map_xform);
	float	zero=	0;
	float	two=	2;
	float4	base;
	asm
	{
//		setGradientH	zero
//		setGradientV	zero
//		setTexLOD		two
		tfetch2D	base,	coord,	base_map, LODBias= 2
	};
*/
	float4	detail=	SAMPLE_ALBEDO_TEXTURE(detail_map, transform_texcoord(texcoord, detail_map_xform));

	albedo.rgb= base.rgb * (detail.rgb * DETAIL_MULTIPLIER) * albedo_color.rgb;
	albedo.w= base.w*detail.w*albedo_color.w;

	apply_pc_albedo_modifier(albedo, normal);
}

sampler detail_map2;
float4 detail_map2_xform;

void calc_albedo_detail_blend_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=		SAMPLE_ALBEDO_TEXTURE(base_map,		transform_texcoord(texcoord, base_map_xform));
	base.w= saturate(base.w*blend_alpha);
	
	float4	detail=		SAMPLE_ALBEDO_TEXTURE(detail_map,	transform_texcoord(texcoord, detail_map_xform));	
	float4	detail2=	SAMPLE_ALBEDO_TEXTURE(detail_map2,	transform_texcoord(texcoord, detail_map2_xform));

	albedo.xyz= (1.0f-base.w)*detail.xyz + base.w*detail2.xyz;
	albedo.xyz= DETAIL_MULTIPLIER * base.xyz*albedo.xyz;
	albedo.w= (1.0f-base.w)*detail.w + base.w*detail2.w;

	apply_pc_albedo_modifier(albedo, normal);
}

sampler detail_map3;
float4 detail_map3_xform;

void calc_albedo_three_detail_blend_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4 base=	SAMPLE_ALBEDO_TEXTURE(base_map,		transform_texcoord(texcoord, base_map_xform));
	base.w= saturate(base.w*blend_alpha);
	
	float4 detail1= SAMPLE_ALBEDO_TEXTURE(detail_map,	transform_texcoord(texcoord, detail_map_xform));
	float4 detail2= SAMPLE_ALBEDO_TEXTURE(detail_map2,	transform_texcoord(texcoord, detail_map2_xform));
	float4 detail3= SAMPLE_ALBEDO_TEXTURE(detail_map3,	transform_texcoord(texcoord, detail_map3_xform));

	float blend1= saturate(2.0f*base.w);
	float blend2= saturate(2.0f*base.w - 1.0f);

	float4 first_blend=  (1.0f-blend1)*detail1		+ blend1*detail2;
	float4 second_blend= (1.0f-blend2)*first_blend	+ blend2*detail3;

	albedo.rgb= DETAIL_MULTIPLIER * base.rgb * second_blend.rgb;
	albedo.a= second_blend.a;

	apply_pc_albedo_modifier(albedo, normal);
}

sampler change_color_map;
float4 change_color_map_xform;
sampler decal_change_color_map;
float4 decal_change_color_map_xform;

float3 primary_change_color;
float3 secondary_change_color;
float3 tertiary_change_color;
float3 quaternary_change_color;

void calc_albedo_two_change_color_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4 base=			SAMPLE_ALBEDO_TEXTURE(base_map,			transform_texcoord(texcoord, base_map_xform));
	float4 detail=			SAMPLE_ALBEDO_TEXTURE(detail_map,		transform_texcoord(texcoord, detail_map_xform));
	float2 change_color_mask=	SAMPLE_ALBEDO_TEXTURE(change_color_map, transform_texcoord(texcoord, change_color_map_xform));

	float3 change_color=	(1.0f - change_color_mask.x + change_color_mask.x * primary_change_color.rgb) *
							(1.0f - change_color_mask.y + change_color_mask.y * secondary_change_color.rgb);

	albedo.xyz= DETAIL_MULTIPLIER * base.xyz*detail.xyz*change_color.xyz;
	albedo.w= base.w*detail.w;
	
	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_four_change_color_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4 base=			SAMPLE_ALBEDO_TEXTURE(base_map,			transform_texcoord(texcoord, base_map_xform));
	float4 detail=			SAMPLE_ALBEDO_TEXTURE(detail_map,		transform_texcoord(texcoord, detail_map_xform));
	float4 change_color_mask=	SAMPLE_ALBEDO_TEXTURE(change_color_map,	transform_texcoord(texcoord, change_color_map_xform));

	float3 change_color=	(1.0f - change_color_mask.x + change_color_mask.x*primary_change_color.rgb)*
						(1.0f - change_color_mask.y + change_color_mask.y*secondary_change_color.rgb)*
						(1.0f - change_color_mask.z + change_color_mask.z*tertiary_change_color.rgb)*
						(1.0f - change_color_mask.w + change_color_mask.w*quaternary_change_color.rgb);

	albedo.xyz= DETAIL_MULTIPLIER * base.xyz*detail.xyz*change_color.xyz;
	albedo.w= base.w*detail.w;
	
	apply_pc_albedo_modifier(albedo, normal);

}

void calc_albedo_four_change_color_applying_to_specular_ps(in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	calc_albedo_four_change_color_ps(texcoord, albedo, normal);
}

sampler detail_map_overlay;
float4 detail_map_overlay_xform;

void calc_albedo_two_detail_overlay_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=				SAMPLE_ALBEDO_TEXTURE(base_map,				transform_texcoord(texcoord, base_map_xform));
	float4	detail=				SAMPLE_ALBEDO_TEXTURE(detail_map,			transform_texcoord(texcoord, detail_map_xform));	
	float4	detail2=			SAMPLE_ALBEDO_TEXTURE(detail_map2,			transform_texcoord(texcoord, detail_map2_xform));
	float4	detail_overlay=		SAMPLE_ALBEDO_TEXTURE(detail_map_overlay,	transform_texcoord(texcoord, detail_map_overlay_xform));

	float4 detail_blend= (1.0f-base.w)*detail + base.w*detail2;
	
	albedo.xyz= base.xyz * (DETAIL_MULTIPLIER * DETAIL_MULTIPLIER) * detail_blend.xyz * detail_overlay.xyz;
	albedo.w= detail_blend.w * detail_overlay.w;

	apply_pc_albedo_modifier(albedo, normal);
}


void calc_albedo_two_detail_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=				SAMPLE_ALBEDO_TEXTURE(base_map,				transform_texcoord(texcoord, base_map_xform));
	float4	detail=				SAMPLE_ALBEDO_TEXTURE(detail_map,			transform_texcoord(texcoord, detail_map_xform));	
	float4	detail2=			SAMPLE_ALBEDO_TEXTURE(detail_map2,			transform_texcoord(texcoord, detail_map2_xform));
	
	albedo.xyz= base.xyz * (DETAIL_MULTIPLIER * DETAIL_MULTIPLIER) * detail.xyz * detail2.xyz;
	albedo.w= base.w * detail.w * detail2.w;

	apply_pc_albedo_modifier(albedo, normal);
}


sampler color_mask_map;
float4 color_mask_map_xform;
float4 neutral_gray;

void calc_albedo_color_mask_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=	SAMPLE_ALBEDO_TEXTURE(base_map,   transform_texcoord(texcoord, base_map_xform));
	float4	detail=	SAMPLE_ALBEDO_TEXTURE(detail_map, transform_texcoord(texcoord, detail_map_xform));
	float4  color_mask=	SAMPLE_ALBEDO_TEXTURE(color_mask_map,	transform_texcoord(texcoord, color_mask_map_xform));

	float4 tint_color=	((1.0f-color_mask.x) + color_mask.x * albedo_color.xyzw / float4(neutral_gray.xyz, 1.0f))		*		// ###ctchou $PERF do this divide in the pre-process
						((1.0f-color_mask.y) + color_mask.y * albedo_color2.xyzw / float4(neutral_gray.xyz, 1.0f))		*
						((1.0f-color_mask.z) + color_mask.z * albedo_color3.xyzw / float4(neutral_gray.xyz, 1.0f));

	albedo.rgb= base.rgb * (detail.rgb * DETAIL_MULTIPLIER) * tint_color.rgb;
	albedo.w= base.w * detail.w * tint_color.w;

	apply_pc_albedo_modifier(albedo, normal);
}

void calc_albedo_two_detail_black_point_ps(
	in float2 texcoord,
	out float4 albedo,
	in float3 normal)
{
	float4	base=				SAMPLE_ALBEDO_TEXTURE(base_map,				transform_texcoord(texcoord, base_map_xform));
	float4	detail=				SAMPLE_ALBEDO_TEXTURE(detail_map,			transform_texcoord(texcoord, detail_map_xform));	
	float4	detail2=			SAMPLE_ALBEDO_TEXTURE(detail_map2,			transform_texcoord(texcoord, detail_map2_xform));
	
	albedo.xyz= base.xyz * (DETAIL_MULTIPLIER * DETAIL_MULTIPLIER) * detail.xyz * detail2.xyz;
	albedo.w= apply_black_point(base.w, detail.w * detail2.w);

	apply_pc_albedo_modifier(albedo, normal);
}


void integrate_analytcial_mask(inout float4 albedo, float specular_mask_scale)
{
#ifdef BLEND_MODE_OFF
	albedo.w*= specular_mask_scale;
	albedo.w= sqrt(albedo.w);
#endif // BLEND_MODE_OFF
}


void restore_specular_mask(inout float4 albedo, float specular_mask_scale)
{
#ifdef BLEND_MODE_OFF
	albedo.w*=albedo.w;
	albedo.w/= specular_mask_scale;
#endif // BLEND_MODE_OFF
}


#endif