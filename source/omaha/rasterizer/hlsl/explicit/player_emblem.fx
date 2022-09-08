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
#include "explicit\emblem_registers.fx"


float sample_element(
	texture_sampler_2d emblem_sampler,
	float2		texcoord,
	float3x2	transform,
	float4		params,
	float		gradient_magnitude)
{
	float2	emblem_texcoord=	mul(float3(texcoord.xy, 1.0f), transform);
	float	vector_distance=	sample2D(emblem_sampler, emblem_texcoord).g + params.z;
	float	scale=				max(params.y / gradient_magnitude, 1.0f);		// scales smaller than 1.0 result in '100% transparent' areas appearing as semi-opaque
	float	vector_alpha=		saturate((vector_distance - 0.5f) * min(scale, params.x) + 0.5f);

	return	vector_alpha;
}


float4 calc_emblem_reach_original(
	in float2 texcoord,
	uniform bool multilayered)
{
	float gradient_magnitude;
	{
#if defined(pc) && (DX_VERSION == 9)
		gradient_magnitude= 0.001f;
#elif DX_VERSION == 11
		float4 gradients= GetGradients(texcoord);
		gradient_magnitude= sqrt(dot(gradients.xyzw, gradients.xyzw));
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

static float get_emblem_pixel_for_channel(float channel_value, bool flip)
{
	if (flip)
	{
		channel_value= 1.f-channel_value;
	}

	return channel_value;
}

static float4 generate_h3_compatible_emblem_pixel(float2 texcoord)
{
	bool emblem_alternate_foreground_channel_enabled= (background_color.a!=0);
	bool emblem_flip_foreground= (foreground_color.a!=0);
	bool emblem_flip_background= (midground_color.a!=0);

	// foreground channel(s), weighted by alpha
	float4 fore_pixel= float4(0.0f, 0.0f, 0.0f, 0.0f);
	{
		float4 emblem_foreground_pixel= sample2D(foreground0_sampler, texcoord);
		float value= get_emblem_pixel_for_channel(emblem_foreground_pixel.g, emblem_flip_foreground);
		fore_pixel.rgb= foreground_color.rgb * value;
		fore_pixel.a= value;

		// blend alternate foreground channel over original
		if (emblem_alternate_foreground_channel_enabled)
		{
			float value= get_emblem_pixel_for_channel(emblem_foreground_pixel.r, emblem_flip_foreground);
			fore_pixel.rgb= fore_pixel.rgb * (1-value) + midground_color.rgb * value;
			fore_pixel.a= saturate(fore_pixel.a + value);
		}
	}

	// background channel
	float back_pixel;
	{
		float4 emblem_background_pixel= sample2D(background0_sampler, texcoord);
		back_pixel= get_emblem_pixel_for_channel(emblem_background_pixel.b, emblem_flip_background);
	}

	// blend foreground over background
	float4 out_pixel;
	out_pixel.rgb= background_color.rgb * back_pixel * (1-fore_pixel.a) + fore_pixel.rgb;
	out_pixel.a= saturate(back_pixel + fore_pixel.a);

	// normalize color for alpha blend
	out_pixel.rgb/= max(out_pixel.a, 0.001f);

	return out_pixel;
}

float4 calc_emblem(
	in float2 texcoord,
	uniform bool multilayered)
{
#ifdef USE_REACH_EMBLEMS
        return calc_emblem_reach_original(in float2 texcoord, uniform bool multilayered);
#else
        float4 h3_compatible_emblem_pixel = generate_h3_compatible_emblem_pixel(texcoord);
        h3_compatible_emblem_pixel.a = (1.0 - h3_compatible_emblem_pixel.a);
        return h3_compatible_emblem_pixel;
#endif
}


#endif //__PLAYER_EMBLEM_FX__
