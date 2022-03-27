/*
player_emblem.fx
Copyright (c) Microsoft Corporation, 2009. All rights reserved.
Monday August 31, 2009, 12:01pm ctchou

	player emblems have 3 layers	(background, middground, foreground)
		each successive layer composites on top of the previous layer
		each layer consists of a single channel alpha-map tinted by a color
		the alpha map is composed of a blend of two shapes
			the blend is: saturate(shape1 * scale1 + shape2 * scale2)
			using positive and negative scales, this allows overlay, subtraction or alpha blend between the two shapes in a layer
			each shape can apply a 2x2 matrix to allow arbitrarily flip, rotate, scale and skew		// (if we limit to flip/rotate only, we can save alot of gradient operations)
			each shape is stored as an atlased vector-map texture that supports high-precision antialiasing
				each color channel of the vector-map can store a separate shape.  the shapes in each layer can source from any color channel (instead of being linked to a particular color channel as before)
*/

#ifndef __PLAYER_EMBLEM_FX__
#define __PLAYER_EMBLEM_FX__

// ---------- headers

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

// ---------- constants

#include "hlsl_registers.fx"
#define	SHADER_CONSTANT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, register_bank, stage, command_buffer_option)		hlsl_type hlsl_name stage##_REGISTER(register_bank##register_start);
	#include "hlsl_constant_declaration_defaults.fx"
	#include "explicit\emblem_registers.fx"
	#include "hlsl_constant_declaration_defaults_end.fx"
#undef SHADER_CONSTANT
#undef VERTEX_REGISTER
#undef PIXEL_REGISTER


float sample_element(
	sampler		emblem_sampler,
	float2		texcoord,
	float3x2	transform,
	float4		params,
	float		gradient_magnitude)
{
	float2	emblem_texcoord=	mul(float3(texcoord.xy, 1.0f), transform);
	float	vector_distance=	tex2D(emblem_sampler, emblem_texcoord).g + params.z;
	float	scale=				max(params.y / gradient_magnitude, 1.0f);		// scales smaller than 1.0 result in '100% transparent' areas appearing as semi-opaque
	float	vector_alpha=		saturate((vector_distance - 0.5f) * min(scale, params.x) + 0.5f);

	return	vector_alpha;
}


float4 calc_emblem(
	in float2 texcoord,
	uniform bool multilayered)
{
	float gradient_magnitude;
	{
#ifdef pc
		gradient_magnitude= 0.001f;
#else // !pc
		float4 gradients;
		asm {
			getGradients gradients, texcoord, foreground1_sampler
		};
		gradient_magnitude= sqrt(dot(gradients.xyzw, gradients.xyzw));
#endif // !pc
	}

	float4 result=	float4(0.0f, 0.0f, 0.0f, 1.0f);
		
	if (multilayered)
	{
		{
			[isolate]
			float back0=	sample_element(	background0_sampler,	texcoord,	background_xform[0],	background_params[0],	gradient_magnitude);
			float back1=	sample_element(	background1_sampler,	texcoord,	background_xform[1],	background_params[1],	gradient_magnitude);
			float back=		saturate(back0 * background_params[0].w + back1 * background_params[1].w) * background_color.a;
	
			result		*=	(1-back);
			result.rgb	+=	back * sqrt(background_color.rgb);
		}

		{
			[isolate]
			float mid0=		sample_element(	midground0_sampler,		texcoord,	midground_xform[0],		midground_params[0],	gradient_magnitude);
			float mid1=		sample_element(	midground1_sampler,		texcoord,	midground_xform[1],		midground_params[1],	gradient_magnitude);
			float mid=		saturate(mid0 * midground_params[0].w +	mid1 * midground_params[1].w) * midground_color.a;
		
			result		*=	(1-mid);
			result.rgb	+=	mid * sqrt(midground_color.rgb);
		}
	}

	{
		[isolate]
		float fore0=	sample_element(	foreground0_sampler,	texcoord,	foreground_xform[0],	foreground_params[0],	gradient_magnitude);
		float fore1=	sample_element(	foreground1_sampler,	texcoord,	foreground_xform[1],	foreground_params[1],	gradient_magnitude);
		float fore=		saturate(fore0 * foreground_params[0].w +	fore1 * foreground_params[1].w) * foreground_color.a;

		result		*=	(1-fore);
		result.rgb	+=	fore * sqrt(foreground_color.rgb);
	}

	return result;
}








/*
// the setting of these constants controls the shader output
// in the game shell UI, the UI rendering code for emblems would set the appropriate shader constants
// for rendering on the in-game player, the desire would be to have object functions used to set these
// the 3 bool constants are stored in alpha channels of the color components
// passed into the shaders b/c no way to get bool values into shaders from object functions
PIXEL_CONSTANT(float4, emblem_color_background_argb, c55);
PIXEL_CONSTANT(float4, emblem_color_icon1_argb, c56);
PIXEL_CONSTANT(float4, emblem_color_icon2_argb, c57);

sampler2D tex0_sampler : register(s0);
sampler2D tex1_sampler : register(s1);

// ---------- private code

static float get_emblem_pixel_for_channel(float channel_value, bool flip)
{
	if (flip)
	{
		channel_value= 1.f-channel_value;
	}
	
	return channel_value;
}

static float4 generate_emblem_pixel(float2 texcoord) : COLOR
{
	
	//	tex0_sampler == emblem background texture bitmap, ARGB format (NOTE: alpha channel ignored)
	//	tex1_sampler == emblem foreground texture bitmap, ARGB format (NOTE: alpha channel ignored)
	//	emblem_pixel.b == background icon
	//	emblem_pixel.g == foreground icon 1
	//	emblem_pixel.r == foreground icon 2 - can be toggled on or off (emblem_alternate_foreground_channel_enabled)
	//	emblem_pixel.a == boolean flag :
	//	emblem_color_background.a == "emblem_alternate_foreground_channel_enabled"
	//	emblem_color_icon1.a == "emblem_flip_foreground"
	//	emblem_color_icon2.a == "emblem_flag_flip_background"
	
	
	bool emblem_alternate_foreground_channel_enabled= (emblem_color_background_argb.a!=0);
	bool emblem_flip_foreground= (emblem_color_icon1_argb.a!=0);
	bool emblem_flip_background= (emblem_color_icon2_argb.a!=0);
	
	// foreground channel(s), weighted by alpha
	float4 fore_pixel= float4(0.0f, 0.0f, 0.0f, 0.0f);
	{
		float4 emblem_foreground_pixel= tex2D(tex1_sampler, texcoord);
		float value= get_emblem_pixel_for_channel(emblem_foreground_pixel.g, emblem_flip_foreground);
		fore_pixel.rgb= emblem_color_icon1_argb.rgb * value;
		fore_pixel.a= value;
		
		// blend alternate foreground channel over original
		if (emblem_alternate_foreground_channel_enabled)
		{
			float value= get_emblem_pixel_for_channel(emblem_foreground_pixel.r, emblem_flip_foreground);
			fore_pixel.rgb= fore_pixel.rgb * (1-value) + emblem_color_icon2_argb.rgb * value;
			fore_pixel.a= saturate(fore_pixel.a + value);
		}
	}

	// background channel
	float back_pixel;
	{
		float4 emblem_background_pixel= tex2D(tex0_sampler, texcoord);
		back_pixel= get_emblem_pixel_for_channel(emblem_background_pixel.b, emblem_flip_background);
	}
	
	// blend foreground over background
	float4 out_pixel;
	out_pixel.rgb= emblem_color_background_argb.rgb * back_pixel * (1-fore_pixel.a) + fore_pixel.rgb;
	out_pixel.a= saturate(back_pixel + fore_pixel.a);
	
	// normalize color for alpha blend	
	out_pixel.rgb/= max(out_pixel.a, 0.001f);
	
	return out_pixel;
}


*/



// see above
#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT


#endif //__PLAYER_EMBLEM_FX__
