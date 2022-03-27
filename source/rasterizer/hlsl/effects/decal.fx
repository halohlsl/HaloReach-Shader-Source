/*
DECAL.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

#define SCOPE_MESH_DEFAULT

#include "shared\blend.fx"
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

#include "effects\decal_registers.fx"

// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
// We could automatically prepend this to the shader file when doing generate-templates, hmmm...
#ifndef category_albedo
extern int category_albedo;
#endif
#ifndef category_blend_mode
extern int category_blend_mode;
#endif
#ifndef category_render_pass
extern int category_render_pass;
#endif
#ifndef category_specular
extern int category_specular;
#endif
#ifndef category_bump_mapping
extern int category_bump_mapping;
#endif
#ifndef category_tinting
extern int category_tinting;
#endif

// We set the sampler address mode to black border in the render_method_option.  That guarantees no effect
// for most blend modes, but not all.  For the other modes, we do a pixel kill.
#define BLACK_BORDER_INSUFFICIENT (TEST_CATEGORY_OPTION(blend_mode, opaque) \
|| TEST_CATEGORY_OPTION(blend_mode, multiply)								\
|| TEST_CATEGORY_OPTION(blend_mode, double_multiply)						\
|| TEST_CATEGORY_OPTION(blend_mode, inv_alpha_blend))						\

// Even with this turned on, we get z-fighting, because the decal is not guaranteed to list the
// verts in the same order as the underlying mesh
#undef REPRODUCIBLE_Z

#include "hlsl_vertex_types.fx"
#include "templated\deform.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#include "explicit\player_emblem.fx"

#ifdef VERTEX_SHADER
#define IS_FLAT_VERTEX (IS_VERTEX_TYPE(s_flat_world_vertex) || IS_VERTEX_TYPE(s_flat_rigid_vertex) || IS_VERTEX_TYPE(s_flat_skinned_vertex))
#else
#define IS_FLAT_VERTEX (TEST_CATEGORY_OPTION(bump_mapping, leave) && TEST_CATEGORY_OPTION(parallax, off) && TEST_CATEGORY_OPTION(interier, off))
#endif

#define BLEND_MODE_SELF_ILLUM (TEST_CATEGORY_OPTION(blend_mode, additive) || TEST_CATEGORY_OPTION(blend_mode, add_src_times_srcalpha))

extern float u_tiles;
extern float v_tiles;

struct s_decal_interpolators
{
	float4 m_position	:POSITION0;
	float4 m_texcoord	:TEXCOORD0;
#if !IS_FLAT_VERTEX
	float3 m_tangent	:TEXCOORD1;	
	float3 m_binormal	:TEXCOORD2;	
	float3 m_normal		:TEXCOORD3;
#endif
	float3 fragment_to_camera_world: TEXCOORD4;
};

s_decal_interpolators default_vs( vertex_type IN )
{
	s_decal_interpolators OUT;

	float4 local_to_world_transform[3];
	float3 binormal;
	IN.position.w= 0; // we never need binormal decompression. this saved 1 GPR, 3 ALUs.
	always_local_to_view(IN, local_to_world_transform, OUT.m_position, binormal);

	// Record both the normalized and sprite texcoord, for use in pixel kill and tfetch
	if (pixel_kill_enabled)
	{
		OUT.m_texcoord= float4(IN.texcoord, IN.texcoord * sprite.zw + sprite.xy);
	}
	else
	{
		OUT.m_texcoord= float4(0.5f, 0.5f, IN.texcoord * sprite.zw + sprite.xy);
	}
	
	OUT.m_texcoord.zw*= float2(u_tiles, v_tiles);
	
#if !IS_FLAT_VERTEX
	OUT.m_normal= IN.normal;	// currently, decals are always in world space
	OUT.m_tangent= IN.tangent;
	OUT.m_binormal= binormal;
#endif
	OUT.fragment_to_camera_world= Camera_Position - IN.position;
	
	return OUT;
}

extern sampler base_map;
float4 base_map_xform;
extern sampler alpha_map;
float4 alpha_map_xform;
extern sampler palette;
float4 palette_xform;
float alpha_min;
float alpha_max;

// Don't apply gamma twice!  This should really be taken care of in render_target.fx . 
#if TEST_CATEGORY_OPTION(blend_mode, multiply) || TEST_CATEGORY_OPTION(blend_mode, double_multiply)
#define LDR_gamma2 false
#define HDR_gamma2 false
#endif

#define BLEND_MODE_USES_SRC_ALPHA (!(						\
	TEST_CATEGORY_OPTION(blend_mode, opaque) ||				\
	TEST_CATEGORY_OPTION(blend_mode, additive) ||			\
	TEST_CATEGORY_OPTION(blend_mode, multiply) ||			\
	TEST_CATEGORY_OPTION(blend_mode, double_multiply) ||	\
	TEST_CATEGORY_OPTION(blend_mode, maximum) ||			\
	TEST_CATEGORY_OPTION(blend_mode, multiply_add)			\
))

#include "shared\albedo_pass.fx"
#include "shared\render_target.fx"
#include "templated\bump_mapping.fx"

#define RENDER_TARGET_ALBEDO_ONLY			0
#define RENDER_TARGET_ALBEDO_AND_NORMAL		1
#define RENDER_TARGET_LIGHTING				2

#if TEST_CATEGORY_OPTION(render_pass, post_lighting)
#define RENDER_TARGET_TYPE RENDER_TARGET_LIGHTING
#elif !TEST_CATEGORY_OPTION(bump_mapping, leave)
#define RENDER_TARGET_TYPE RENDER_TARGET_ALBEDO_AND_NORMAL
#else
#define RENDER_TARGET_TYPE RENDER_TARGET_ALBEDO_ONLY
#endif

sampler vector_map;
float antialias_tweak;
float vector_sharpness;
sampler shadow_vector_map;
float4 shadow_vector_map_xform;
float shadow_offset_u;
float shadow_offset_v;
float shadow_darkness;
float shadow_sharpness;


sampler change_color_map;
float3 primary_change_color;
float3 secondary_change_color;
float3 tertiary_change_color;


float height_scale;

sampler height_map;
float4 height_map_xform;


sampler interier;
float4 interier_xform;

sampler wall_map;
float4 wall_map_xform;

float thin_shell_height;
float mask_threshold;
float hole_radius;
float box_size;

float fog_factor;
float3 fog_top_color;
float3 fog_bottom_color;

float sphere_radius;
float sphere_height;



float4 sample_diffuse(float2 texcoord_tile, float2 texcoord, float palette_v)
{
	IF_CATEGORY_OPTION(albedo, diffuse_only)
	{
		return tex2D(base_map, transform_texcoord(texcoord, base_map_xform));
	}
	
	// Same as above except the alpha comes from a separate texture.
	IF_CATEGORY_OPTION(albedo, diffuse_plus_alpha)
	{
		return float4(tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).xyz, tex2D(alpha_map, transform_texcoord(texcoord, alpha_map_xform)).w);
	}
	
	// Same as above except the alpha is always a single tile even if the decal is a sprite, or tiled.
	IF_CATEGORY_OPTION(albedo, diffuse_plus_alpha_mask)
	{
		return float4(tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).xyz, tex2D(alpha_map, transform_texcoord(texcoord_tile, alpha_map_xform)).w);
	}
	
	// Dependent texture fetch.  The palette can be any size.  In order to avoid filtering artifacts,
	// the palette should be smoothly varying, or else filtering should be turned off.
	IF_CATEGORY_OPTION(albedo, palettized)
	{
		float index= tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).x;
		return tex2D(palette, float2(index, palette_v));
	}
	
	// Same as above except the alpha comes from the original texture, not the palette.
	IF_CATEGORY_OPTION(albedo, palettized_plus_alpha)
	{
		float index= tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).x;
		float alpha= tex2D(alpha_map, transform_texcoord(texcoord, base_map_xform)).w;
		return float4(tex2D(palette, float2(index, palette_v)).xyz, alpha);
	}
	
	// Same as above except the alpha is always a single tile even if the decal is a sprite, or tiled.
	IF_CATEGORY_OPTION(albedo, palettized_plus_alpha_mask)
	{
		float index= tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).x;
		float alpha= tex2D(alpha_map, transform_texcoord(texcoord_tile, base_map_xform)).w;
		return float4(tex2D(palette, float2(index, palette_v)).xyz, alpha);
	}
	
	IF_CATEGORY_OPTION(albedo, emblem_change_color)
	{
		float4 emblem=	calc_emblem(texcoord_tile, true);
		return float4(emblem.rgb, 1.0f - emblem.a);
	}
	
	IF_CATEGORY_OPTION(albedo, patchy_emblem)
	{
		float4 emblem=	calc_emblem(texcoord_tile, true);
		float alpha=	tex2D(alpha_map, transform_texcoord(texcoord_tile, alpha_map_xform)).a;
		alpha=	saturate(lerp(alpha_min, alpha_max, alpha));
	
		return float4(emblem.rgb, (1.0f - emblem.a)*alpha);
	}

	IF_CATEGORY_OPTION(albedo, change_color)
	{
		float4 change_color= tex2D(change_color_map, texcoord);

		change_color.xyz=	((1.0f-change_color.x) + change_color.x*primary_change_color.xyz)	*
							((1.0f-change_color.y) + change_color.y*secondary_change_color.xyz)	*
							((1.0f-change_color.z) + change_color.z*tertiary_change_color.xyz);

		return change_color;
	}
	
	IF_CATEGORY_OPTION(albedo, vector_alpha)
	{
		float3 color=				tex2D(base_map, transform_texcoord(texcoord, base_map_xform)).rgb;
		float  vector_distance=		tex2D(vector_map, texcoord).g;
		
		float scale= antialias_tweak;
#ifdef pc
		scale /= 0.001f;
#else // !pc
		float4 gradients;
		asm {
			getGradients gradients, texcoord, vector_map
		};
		scale /= sqrt(dot(gradients.xyzw, gradients.xyzw));
#endif // !pc
		scale= max(scale, 1.0f);		// scales smaller than 1.0 result in '100% transparent' areas appearing as semi-opaque

		float vector_alpha= saturate((vector_distance - 0.5f) * min(scale, vector_sharpness) + 0.5f);

		return float4(color * vector_alpha, vector_alpha);
	}	
	
	IF_CATEGORY_OPTION(albedo, vector_alpha_drop_shadow)
	{
		float vector_distance=		tex2D(vector_map, texcoord).g;
		float shadow_distance=		tex2D(shadow_vector_map, transform_texcoord(texcoord, shadow_vector_map_xform)).g;
		
		float scale= antialias_tweak;
#ifdef pc
		scale /= 0.001f;
#else // !pc
		float4 gradients;
		asm {
			getGradients gradients, texcoord, vector_map
		};
		scale /= sqrt(dot(gradients.xyzw, gradients.xyzw));
#endif // !pc
		scale= max(scale, 1.0f);		// scales smaller than 1.0 result in '100% transparent' areas appearing as semi-opaque

		float shadow_alpha= saturate((shadow_distance - 0.5f) * min(scale, shadow_sharpness) + 0.5f) * shadow_darkness;
		float vector_alpha= saturate((vector_distance - 0.5f) * min(scale, vector_sharpness) + 0.5f);

		{
#ifndef pc
			[isolate]
#endif // !pc
			float3 color=				tex2D(base_map,	  transform_texcoord(texcoord, base_map_xform)).rgb;
			return float4(color * vector_alpha, vector_alpha + shadow_alpha);
		}
	}	
}

float3x3 tangent_frame(s_decal_interpolators IN)
{
#if IS_FLAT_VERTEX
	return 0.0f;
#else
	return float3x3(IN.m_tangent, IN.m_binormal, IN.m_normal);
#endif
}

float3 sample_bump(float2 texcoord_tile, float2 texcoord, float3x3 tangent_frame)
{
	float3 bump_normal;
	float3 unused= {0.0f, 0.0f, 0.0f};
	
	IF_CATEGORY_OPTION(bump_mapping, leave)
	{
		calc_bumpmap_off_ps(texcoord, unused, tangent_frame, bump_normal);
	}
	
	IF_CATEGORY_OPTION(bump_mapping, standard)
	{
		calc_bumpmap_default_ps(texcoord, unused, tangent_frame, bump_normal);
	}
	
	IF_CATEGORY_OPTION(bump_mapping, standard_mask)
	{
		calc_bumpmap_default_ps(texcoord_tile, unused, tangent_frame, bump_normal);
	}
	
	return bump_normal;
}

extern float4 tint_color;
extern float intensity;
extern float modulation_factor;
void tint_and_modulate(inout float4 diffuse)
{
	float4 tint_color_internal= 1.0f;
	float intensity_internal= 1.0f;
	float modulation_factor_internal= 0.0f;

	IF_CATEGORY_OPTION(tinting, none)
	{
	}
	else 
	{
		tint_color_internal= tint_color;
		intensity_internal= intensity;
		IF_CATEGORY_OPTION(tinting, unmodulated)
		{
		}
		else IF_CATEGORY_OPTION(tinting, fully_modulated)
		{
			modulation_factor_internal= 1.0f;
		}
		else IF_CATEGORY_OPTION(tinting, partially_modulated)
		{
			modulation_factor_internal= modulation_factor;
		}
	}
	
	const static float recip_sqrt_3= 1.0f / 1.7320508f;
	float Y= recip_sqrt_3 * length(diffuse.xyz);
	diffuse.xyz*= lerp(tint_color_internal.xyz, 1.0f, modulation_factor_internal * Y) * intensity_internal;
	
	IF_CATEGORY_OPTION(render_pass, post_lighting)
	{
		IF_CATEGORY_OPTION(blend_mode, multiply)
		{
		}
		else IF_CATEGORY_OPTION(blend_mode, double_multiply)
		{
		}
		else if (BLEND_MODE_SELF_ILLUM)
		{
			diffuse.xyz*= ILLUM_EXPOSURE;
		}
		else
		{
			diffuse.xyz*= g_exposure.x;
		}		
	}
}

// fade out ... cover a few of the common blend modes
void fade_out(inout float4 color)
{
	IF_CATEGORY_OPTION(blend_mode, additive)
	{
		color.xyz*= fade;
	}
	else IF_CATEGORY_OPTION(blend_mode, multiply)
	{
		color.xyz= lerp(1.0f, color.xyz, fade.x);
	}
	else IF_CATEGORY_OPTION(blend_mode, double_multiply)
	{
		color.xyz= lerp(0.5f, color.xyz, fade.x);
	}
	
	// bump and specular needs an alpha even if diffuse doesn't
	if (!IS_FLAT_VERTEX || !TEST_CATEGORY_OPTION(specular, leave) || BLEND_MODE_USES_SRC_ALPHA)
	{
		color.w *= fade.x;
	}
	
	IF_CATEGORY_OPTION(blend_mode, pre_multiplied_alpha)
	{
		IF_CATEGORY_OPTION(albedo, vector_alpha_drop_shadow)
		{
		}
		else IF_CATEGORY_OPTION(albedo, vector_alpha)
		{
		}
		else
		{
			color.xyz *= color.w;
		}
		color.xyz *= fade.x;
	}
}


#if (RENDER_TARGET_TYPE== RENDER_TARGET_LIGHTING)
typedef accum_pixel s_decal_render_pixel_out;
#elif (RENDER_TARGET_TYPE== RENDER_TARGET_ALBEDO_AND_NORMAL)
typedef albedo_pixel s_decal_render_pixel_out;
#else	//if (RENDER_TARGET_TYPE RENDER_TARGET_ALBEDO_ONLY)
struct s_decal_render_pixel_out
{
	float4 m_color0:	COLOR0;
};
#endif

s_decal_render_pixel_out convert_to_decal_target(float4 color, float3 normal)
{
	s_decal_render_pixel_out OUT;
	
#if (RENDER_TARGET_TYPE== RENDER_TARGET_LIGHTING)
	OUT= CONVERT_TO_RENDER_TARGET_FOR_BLEND(color, false, false);
#elif (RENDER_TARGET_TYPE== RENDER_TARGET_ALBEDO_AND_NORMAL)
	OUT= convert_to_albedo_target(color, normal, color.a);
#else	//if (RENDER_TARGET_TYPE RENDER_TARGET_ALBEDO_ONLY)
	OUT.m_color0= color;
#endif
	
	return OUT;
}

float calc_parallax_off_ps(
	in float2 texcoord,
	in float3 view_dir,					// direction towards camera
	out float2 parallax_texcoord)
{
	parallax_texcoord= texcoord;
	return 0;
}

float calc_parallax_simple_ps(
	in float2 texcoord,
	in float3 view_dir,					// direction towards camera
	out float2 parallax_texcoord)
{
	texcoord= transform_texcoord(texcoord, height_map_xform);
	float height_in_texture= tex2D(height_map, texcoord).g;
	float height= ( height_in_texture - 0.5f ) * height_scale;		// ###ctchou $PERF can switch height maps to be signed and get rid of this -0.5 bias
	
	float2 parallax_offset= view_dir.xy * height / view_dir.z;
	
	parallax_texcoord= texcoord + parallax_offset;

	parallax_texcoord= (parallax_texcoord - height_map_xform.zw) / height_map_xform.xy;
	return -length(float3(parallax_offset, height))*sign(height);
}

float calc_parallax_sphere_ps(
	in float2 texcoord,
	in float3 view_dir,					// direction towards camera
	out float2 parallax_texcoord)
{
	float r= sphere_radius*sphere_radius;
	
	float3 start= float3(texcoord.xy, 0);
	float3 sphere_center= float3(0.5, 0.5, sphere_height);
	
	float3 edge_a= sphere_center-start;
	float a= length(edge_a);
	
	if (a>sphere_radius)
	{
		parallax_texcoord.xy= texcoord;
		return 0;
	}
	else
	{
		edge_a= edge_a/a;		
		
		float cosine_r= dot (edge_a, view_dir);
		
		float x= cosine_r*a-sqrt(-a*a+r+a*a*cosine_r*cosine_r);
		
		float3 intersected_edge= start+view_dir*x;
		parallax_texcoord.xy= intersected_edge.xy;
		return -x;
	}
}

#ifndef pc
// This removes the tangent space interpolators if we're not bump mapping.
// It gives us 63 ALU threads instead of 48 for the simplest decals.
// It will cause vertex shader patching, but I think it's worth it.
// No longer needed now that we split into flat and regular vertex types.
//[removeUnusedInputs]
// This keeps the GPR count down to the max number of interpolators, because 
// we want more ALU threads.  Hasn't helped in tests.
//[reduceTempRegUsage(5)]	
#endif

#ifdef PIXEL_SHADER


void update_interier_layer_simple_ps(float2 texcoord, float2 parallax_texcoord, inout float4 diffuse, inout float3 bump, float3 view_dir, float3x3 tangent_frames)
{
	diffuse.a*= 2;
	float layer= diffuse.a-1;
	
	if (layer > mask_threshold)
	{
		diffuse.rgb= tex2D(interier, transform_texcoord(parallax_texcoord, interier_xform));		
	}
	return;	
}

void update_interier_layer_floor_ps(float2 texcoord, float2 parallax_texcoord, inout float4 diffuse, inout float3 bump, float3 view_dir, float3x3 tangent_frames)
{
	diffuse.a*= 2;
	float layer= diffuse.a-1;
	diffuse.a= min(1,diffuse.a);
	
	if (layer > mask_threshold)
	{
		float depth= -thin_shell_height;
		
		float2 parallax_offset= view_dir.xy * depth / view_dir.z;
		
		float2 interier_parallax_texcoord= texcoord + parallax_offset;

		diffuse.rgb= tex2D(interier, transform_texcoord(interier_parallax_texcoord, interier_xform));
		
		bump= tangent_frames[2];
	}
	return;	
}

float3 fog_color(float depth)
{
	float fog_intensity= exp2(fog_factor*depth);
	return lerp(fog_bottom_color, fog_top_color, fog_intensity);
}

void update_interier_layer_hole_ps(float2 texcoord, float2 parallax_texcoord, inout float4 diffuse, inout float3 bump, float3 view_dir, float3x3 tangent_frames)
{
	diffuse.a*= 2;
	float layer= diffuse.a-1;
	diffuse.a= min(1,diffuse.a);
	
	if (layer > mask_threshold)
	{
		float depth= -thin_shell_height;
		
		float2 parallax_offset= view_dir.xy * depth / view_dir.z;		
		float2 interier_parallax_texcoord;

		float3 intersected_edge;
		{		
			float r= hole_radius*hole_radius;
			float u= texcoord.x-0.5f;
			float v= texcoord.y-0.5f;
			
			if (u*u+v*v>r)
			{
				return;
			}
			
			float s= view_dir.x;
			float t= view_dir.y;
			
			float temp_b= - (s*u+t*v);
			float temp_sqrt= r*s*s+r*t*t-t*t*u*u+2*s*t*u*v-s*s*v*v;
			float temp_a= s*s+t*t;
		 
			float solution= (temp_b-sqrt(temp_sqrt))/temp_a;
			float other_solution= (temp_b+sqrt(temp_sqrt))/temp_a;
		 
			intersected_edge= float3(u + s * solution, v + t * solution, view_dir.z * solution);
		}		
		
		if (intersected_edge.z<0)
		{
			if (intersected_edge.z>depth)
			{			
				float2 texcoord= float2(intersected_edge.z,
					hole_radius*atan2(intersected_edge.x, intersected_edge.y));
				
				bump.xy= -intersected_edge.xy;
				bump.z= 0;
				
				bump= mul(bump, tangent_frames);			
				bump= normalize(bump);			
				
				interier_parallax_texcoord= texcoord;				
				diffuse.rgb= tex2D(wall_map, transform_texcoord(interier_parallax_texcoord, wall_map_xform));
				diffuse.rgb= diffuse.rgb * lerp(fog_bottom_color, fog_top_color, exp2(fog_factor*intersected_edge.z));
			}
			else
			{
				interier_parallax_texcoord= texcoord + parallax_offset;
			
				bump= tangent_frames[2];
				
				diffuse.rgb= tex2D(interier, transform_texcoord(interier_parallax_texcoord, interier_xform));
				diffuse.rgb= diffuse.rgb * lerp(fog_bottom_color, fog_top_color, exp2(fog_factor*depth));
			}	
		}
		
	}
	return;	
}


void update_interier_layer_box_ps(float2 texcoord, float2 parallax_texcoord, inout float4 diffuse, inout float3 bump, float3 view_dir, float3x3 tangent_frames)
{
	diffuse.a*= 2;
	float layer= diffuse.a-1;
	diffuse.a= min(1,diffuse.a);
	
	if (layer > mask_threshold)
	{
		float depth= -thin_shell_height;
		
		float2 parallax_offset= view_dir.xy * depth / view_dir.z;		
		float2 interier_parallax_texcoord;

		float3 intersected_edge= 0;
		float3 new_bump= 0;
		{		
			float r= box_size;
			float u= texcoord.x-0.5f;
			float v= texcoord.y-0.5f;
			
			if (abs(u)>r||abs(v)>r)
			{
				return;
			}
			
			float s= view_dir.x;
			float t= view_dir.y;

			float3 candidates[2];
			int direction[2];
			{
				float edge_s= s<0?1:-1;
				direction[0]= edge_s;
				float solution= (edge_s*r-u)/s;
				candidates[0]= float3(u + s * solution, v + t * solution, view_dir.z * solution);
			}
			
			{
				float edge_t= t<0?1:-1;
				direction[1]= edge_t;
				float solution= (edge_t*r-v)/t;
				candidates[1]= float3(u + s * solution, v + t * solution, view_dir.z * solution);
			}
			
			if (candidates[1].z>candidates[0].z)
			{
				intersected_edge= candidates[1];
				new_bump= float3(0,-1,0)*direction[1];
			}
			else
			{
				intersected_edge= candidates[0];
				new_bump= float3(-1,0,0)*direction[0];
			}
		}		
		
		if (intersected_edge.z<0)
		{
			if (intersected_edge.z>depth)
			{
				float2 texcoord= float2(intersected_edge.z,
					intersected_edge.x+intersected_edge.y);
				
				bump= mul(new_bump, tangent_frames);			
				bump= normalize(bump);
				
				interier_parallax_texcoord= texcoord;				
				diffuse.rgb= tex2D(wall_map, transform_texcoord(interier_parallax_texcoord, wall_map_xform));
				diffuse.rgb= diffuse.rgb * fog_color(intersected_edge.z);
			}
			else
			{
				interier_parallax_texcoord= texcoord + parallax_offset;
			
				bump= tangent_frames[2];
				
				diffuse.rgb= tex2D(interier, transform_texcoord(interier_parallax_texcoord, interier_xform));
				diffuse.rgb= diffuse.rgb * fog_color(depth);
			}
		}
	}
	return;	
}


void update_interier_layer_off_ps(float2 texcoord, float2 parallax_texcoord, inout float4 diffuse, inout float3 bump, float3 view_dir, float3x3 tangent_frames)
{
	return;	
}

s_decal_render_pixel_out default_ps(s_decal_interpolators IN)
{
	if (true /*pixel_kill_enabled*/)	// debug render has a performace impact, so moving this to vertex shader
	{
		// This block translates to 2 ALU instructions with no branches.
		// In some cases we can use the built in border address mode instead (see BLACK_BORDER_INSUFFICIENT)
		clip(float4(IN.m_texcoord.xy, 1.0f-IN.m_texcoord.xy));
	}
	
	float2 parallax_texcoord;
	float3 view_dir= IN.fragment_to_camera_world;
	// convert view direction from world space to tangent space
	float3 view_dir_in_tangent_space= mul(tangent_frame(IN), view_dir);	
	
	view_dir_in_tangent_space= normalize(view_dir_in_tangent_space);
	
	float depth_offset= calc_parallax_ps(IN.m_texcoord.zw, view_dir_in_tangent_space, parallax_texcoord);
	float4 diffuse= sample_diffuse(IN.m_texcoord.xy, parallax_texcoord, 0.0f);
	float3 bump= sample_bump(IN.m_texcoord.xy, parallax_texcoord, tangent_frame(IN));
	
	update_interier_layer_ps(IN.m_texcoord.zw, parallax_texcoord, diffuse, bump, view_dir_in_tangent_space, tangent_frame(IN));
	
	tint_and_modulate(diffuse);
	fade_out(diffuse);

	
	return convert_to_decal_target(diffuse, bump);
}

#endif