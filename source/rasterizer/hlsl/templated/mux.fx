//#line 1 "source\rasterizer\hlsl\mux.fx"


#define calc_alpha_test_ps calc_alpha_test_off_ps
#define calc_specular_mask_ps calc_specular_mask_from_diffuse_ps
#define calc_self_illumination_ps calc_self_illumination_none_ps
#define blend_type opaque
#define bitmap_rotation 0

#include "templated\templated_globals.fx"

#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"

sampler material_map;
float4 material_map_xform;
float blend_material_scale;
float blend_material_offset;

#ifdef pc
	static float	mux_index= 0.0;
	static float	mux_blend= 0.0;
	static float4	mux_transform=	0.0;
	float pc_atlas_scale_x;
	float pc_atlas_scale_y;
	float pc_atlas_transform_x;
	float pc_atlas_transform_y;
	float blend_material_count;
#else
	float mux_index;
#endif //pc


void mux_pre_shader(in float2 texcoord)
{
#ifdef pc
	mux_index=			(tex2D(material_map, transform_texcoord(texcoord, material_map_xform)).r * blend_material_scale + blend_material_offset) * blend_material_count;
	
	float2	mux_int_index= 0.0;
	
	mux_int_index.x=	floor(mux_index);
	mux_blend=			mux_index - mux_int_index.x;
	
	mux_int_index=		floor(frac((mux_int_index.xx + float2(0.5f, 1.5f)) / blend_material_count) * blend_material_count);
	
	mux_transform=		mux_int_index.xxyy * float4(pc_atlas_transform_x, pc_atlas_transform_y, pc_atlas_transform_x, pc_atlas_transform_y);
	
#else
	mux_index= tex2D(material_map, transform_texcoord(texcoord, material_map_xform)).a * blend_material_scale + blend_material_offset;
#endif //pc
}
#define PRE_SHADER(texcoord) mux_pre_shader(texcoord)


void mux_pre_material_shader(in float2 texcoord);
#define PRE_MATERIAL_SHADER(texcoord) mux_pre_material_shader(texcoord)


float4 sample_array_texture(in sampler array_texture, in float2 texcoord)
{
#ifdef pc	
	// tile to [0, 1], and scale and offset by mux transform
	float2 tilecoord=	texcoord.xy - floor(texcoord.xy);
	tilecoord=			tilecoord * float2(pc_atlas_scale_x, pc_atlas_scale_y);
	
	float4 lower=	tex2Dlod(array_texture, float4(tilecoord + mux_transform.xy, 0.0f, 0.0f));
	float4 higher=	tex2Dlod(array_texture, float4(tilecoord + mux_transform.zw, 0.0f, 0.0f));
	return lerp(lower, higher, mux_blend);
#else
	float4 result;
	float3 new_texcoord= float3(texcoord, mux_index);
	asm {
		tfetch3D result, new_texcoord, array_texture, OffsetZ=+0.5
	};
	return result;
#endif
}

float3 sample_array_bumpmap(in sampler bump_map, in float2 texcoord)
{
#ifdef pc
	//float3 bump= tex2D(bump_map, texcoord);
	float3 bump= 1;
#else					// xenon compressed bump textures don't calculate z automatically
	float4 bump;
	float3 new_texcoord= float3(texcoord, mux_index);
	asm {
		tfetch3D bump, new_texcoord, bump_map, FetchValidOnly= false, OffsetZ=+0.5
	};
	bump.z= saturate(dot(bump.xy, bump.xy));
	bump.z= sqrt(1 - bump.z);
#endif	
	bump.xyz= normalize(bump.xyz);		// ###ctchou $PERF do we need to normalize?  why?
	
	return bump.xyz;
}

#define SAMPLE_ALBEDO_TEXTURE sample_array_texture
#define SAMPLE_BUMP_TEXTURE sample_array_bumpmap
#define SAMPLE_PARALLAX_TEXTURE sample_array_texture

#include "templated\albedo.fx"
#include "templated\parallax.fx"
#include "templated\bump_mapping.fx"

#include "templated\self_illumination.fx"
#include "templated\specular_mask.fx"
#include "templated\materials\material_models.fx"
#include "templated\environment_mapping.fx"
#include "templated\wetness.fx"
#include "shared\atmosphere.fx"
#include "templated\alpha_test.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"
#include "shared\blend.fx"
#define	BLEND_MODE_OFF		// no blend for mux

#include "shadows\shadow_generate.fx"
#include "shadows\shadow_mask.fx"

#include "templated\active_camo.fx"
#include "templated\velocity.fx"

#include "templated\debug_modes.fx"

#include "templated\entry_points.fx"


#if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_single_lobe_phong
sampler material_property0_map;
sampler material_property1_map;
void mux_pre_material_shader(in float2 texcoord)
{
#ifndef pc
[isolate]
	float4 property0= tex2D(material_property0_map, float2(mux_index, 0.5f));
	float4 property1= tex2D(material_property1_map, float2(mux_index, 0.5f));
	
	specular_tint= property0.rgb;
	diffuse_coefficient= property0.a;
	specular_coefficient= 1.0f;
	area_specular_contribution= property1.r;
	analytical_specular_contribution= property1.g;
	environment_map_specular_contribution= property1.b;
	roughness= property1.a;
#else // pc
#endif // pc
}
#endif // #if MATERIAL_TYPE(material_type) == MATERIAL_TYPE_single_lobe_phong
