//#line 2 "source\rasterizer\hlsl\hdao.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
//@generate screen
//@entry default
//@entry albedo
//@entry static_sh
//@entry shadow_generate
//@entry active_camo
//@entry static_nv_sh



//#include "postprocess\postprocess_registers.fx"
#include "postprocess\hdao_registers.fx"
#include "postprocess\ssao_local_depth_registers.fx"

#define SCREENSHOT_RADIUS_X		(pixel_size.z)
#define SCREENSHOT_RADIUS_Y		(pixel_size.w)

#define CORNER_SCALE	(corner_params.x)
#define CORNER_OFFSET	(corner_params.y)

#define BOUNDS_SCALE	(bounds_params.x)
#define BOUNDS_OFFSET	(bounds_params.y)

#define CURVE_SCALE		(curve_params.x)
#define CURVE_OFFSET	(curve_params.y)
#define CURVE_SIGMA		(curve_params.z)
#define CURVE_SIGMA2	(curve_params.w)					// ignores sample count, for use with screenshots

#define NEAR_SCALE		(fade_params.x)
#define NEAR_OFFSET		(fade_params.y)
#define FAR_SCALE		(fade_params.z)
#define FAR_OFFSET		(fade_params.w)

#define CHANNEL_SCALE	(channel_scale.xyzw)
#define CHANNEL_OFFSET	(channel_offset.xyzw)

struct screen_output
{
	float4 position		:SV_Position;
	float2 texcoord		:TEXCOORD0;
};

#if defined(pc) // --------- pc -------------------------------------------------------------------------------------
screen_output default_vs(in vertex_type IN)
{
	screen_output OUT;
	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	1.0f;
	return OUT;
}
screen_output albedo_vs(in vertex_type IN)
{
	return default_vs(IN);
}
screen_output static_sh_vs(in vertex_type IN)
{
	return default_vs(IN);
}
screen_output shadow_generate_vs(in vertex_type IN)
{
	return default_vs(IN);
}
screen_output active_camo_vs(in vertex_type IN)
{
	return default_vs(IN);
}
screen_output static_nv_sh_vs(in vertex_type IN)
{
	return default_vs(IN);
}
#else		// --------- xenon ----------------------------------------------------------------------------------
screen_output default_vs(in int index : SV_VertexID)
{
	screen_output OUT;

	float	quad_index=		floor(index / 3);						//		[0,	x*y-1]
	float	quad_vertex=	index -	quad_index * 3;					//		[0, 2]

	float2	quad_coords;
	quad_coords.y=	floor(quad_index * quad_tiling.y);				//		[0, y-1]
	quad_coords.x=	quad_index - quad_coords.y * quad_tiling.x;		//		[0, x-1]

	float2	subquad_coords;
	subquad_coords.y=	floor(quad_vertex / 2);						//		[0, 1]
	subquad_coords.x=	quad_vertex - subquad_coords.y * 2;			//		[0, 1]

//	if (subquad_coords.y > 0)
//	{
//		subquad_coords.x= 1-subquad_coords.x;
//	}

	quad_coords += subquad_coords;

	// build interpolator output

	OUT.position.xy=		quad_coords * position_transform.xy + position_transform.zw;
	OUT.position.zw=		depth.zw;
	OUT.texcoord=			quad_coords * texture_transform.xy + texture_transform.zw;

	return OUT;
}
screen_output albedo_vs(in int index : SV_VertexID)
{
	return default_vs(index);
}
screen_output static_sh_vs(in int index : SV_VertexID)
{
	return default_vs(index);
}
screen_output shadow_generate_vs(in int index : SV_VertexID)
{
	return default_vs(index);
}
screen_output active_camo_vs(in int index : SV_VertexID)
{
	return default_vs(index);
}
#endif		// --------- xenon ----------------------------------------------------------------------------------


float calculate_fade(float center_depth)
{
	float near_fade=	saturate(center_depth * NEAR_SCALE + NEAR_OFFSET);
	float far_fade=		saturate(center_depth * FAR_SCALE + FAR_OFFSET);
	float fade=			near_fade * far_fade;

	// smoothing
//	fade=	(3-2*fade)*fade*fade;

	return fade;
}


float calc_occlusion_samples(in float4 depths0, in float4 depths1, in float center_depth)
{
/*
	// traditional HDAO (from paper) -- slightly modified by using a faded far test, instead of a strict cutoff
	// the shadowing factor (DEPTH_TEST) for each depth sample is simply whether it is within a valid range in front of the center sample
	// opposing depth samples must both be shadowing to contribute to occlusion (their shadowing factors are multiplied)

	#define CLOSE_TEST(depths)	(depths > 0.0015f ? 1 : 0)
	#define FAR_TEST(depths)	saturate(1.2f - 3.0 * (depths))
	#define DEPTH_TEST(depths)	(CLOSE_TEST(depths) * FAR_TEST(depths))

	depths0= center_depth	- depths0;
	depths1= center_depth	- depths1;

	depths0=	DEPTH_TEST(depths0);
	depths1=	DEPTH_TEST(depths1);

	return dot(depths0 * depths1, 1.0f);
/*/
	// improved method (ctchou)
	// the shadowing factor is a combination of:
	//   depression amount (how much the center sample is below the average of the two outer opposing depth samples)
	//   bounds amount (whether the nearest depth sample is within shadowing range of the center sample)
	// all depth comparisons are scaled by the distance to the center sample, so that the effect scales with distance


//	#define FAR_TEST(depths)	saturate(1.1f - bounds_scale * (depths))
//	float bounds_scale=		5.0f / abs(center_depth);
//	float4 bounds=			FAR_TEST(center_depth - min(depths0, depths1));


	float4 bounds1=			saturate(BOUNDS_OFFSET + depths0 * (BOUNDS_SCALE / center_depth));
	float4 bounds2=			saturate(BOUNDS_OFFSET + depths1 * (BOUNDS_SCALE / center_depth));
	float4 bounds=	bounds1*bounds2;

//	float4 bounds=			saturate(BOUNDS_OFFSET + min(depths0, depths1) * (BOUNDS_SCALE / center_depth));
//	bounds *= bounds;		// the square based on bounds here is relatively expensive


//	float depression_scale=	20 / abs(center_depth);
//	float4 depression=		saturate(depression_scale * (center_depth * 2.0 - (depths0 + depths1)));

//	float4 depression=		saturate(25 * (2.0 - (depths0 + depths1) / center_depth));
	float4 depression=		saturate(CORNER_OFFSET + (depths0 + depths1) * (CORNER_SCALE / center_depth));

	return dot(bounds * depression, 1.0f);


	// better, but more expensive, do separate bounds tests for each depth
//	float4 bounds1=			FAR_TEST(center_depth - depths0);
//	float4 bounds2=			FAR_TEST(center_depth - depths1);
//	float4 bounds1=			saturate(BOUNDS_OFFSET + (center_depth - depths0) * (BOUNDS_SCALE / center_depth));
//	float4 bounds2=			saturate(BOUNDS_OFFSET + (center_depth - depths1) * (BOUNDS_SCALE / center_depth));
//	return dot(depression * bounds1 * bounds2, 1.0f);

//*/
}


void fix_depth_deproject(inout float4 depths)
{
	depths=	1.0f / (local_depth_constants.xxxx + depths * local_depth_constants.yyyy);
}

void fix_depth_scale(inout float4 depths)
{
//	depths *= 16.0f;
}


#ifdef xenon

#define CALC_OCCLUSION(samp, fix_depth,		DX0, DY0,		DX1, DY1)																											\
{																																												\
	[isolate]																																									\
	asm																																											\
	{																																											\
		tfetch2D	depths0.r___, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DX0, OffsetY= -DY0						\
		tfetch2D	depths0._r__, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DX1, OffsetY= -DY1						\
		tfetch2D	depths0.__r_, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DY0, OffsetY= +DX0						\
		tfetch2D	depths0.___r, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DY1, OffsetY= +DX1						\
																																												\
		tfetch2D	depths1.r___, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DX0, OffsetY= +DY0						\
		tfetch2D	depths1._r__, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DX1, OffsetY= +DY1						\
		tfetch2D	depths1.__r_, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DY0, OffsetY= -DX0						\
		tfetch2D	depths1.___r, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DY1, OffsetY= -DX1						\
	};																																											\
																																												\
	fix_depth(depths0);																																							\
	fix_depth(depths1);																																							\
																																												\
	occlusion	+=	calc_occlusion_samples(depths0, depths1, center_depth);																										\
}


#define CALC_OCCLUSION4(samp, fix_depth,		DX0, DY0)																														\
{																																												\
	{																																											\
		[isolate]																																								\
		asm																																										\
		{																																										\
			tfetch2D	depths0.rgba, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DX0, OffsetY= -DY0					\
			tfetch2D	depths1.rgba, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DX0, OffsetY= +DY0					\
		};																																										\
	}																																											\
	occlusion	+=	calc_occlusion_samples(depths0.xyzw, depths1.xyzw, center_depth);																							\
	{																																											\
		[isolate]																																								\
		asm																																										\
		{																																										\
			tfetch2D	depths0.rgba, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= -DY0, OffsetY= +DX0					\
			tfetch2D	depths1.rgba, texcoord, samp, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +DY0, OffsetY= -DX0					\
		};																																										\
	}																																											\
	occlusion	+=	calc_occlusion_samples(depths0.xyzw, depths1.xyzw, center_depth);																							\
}

#elif DX_VERSION == 11

#define CALC_OCCLUSION(samp, fix_depth,		DX0, DY0,		DX1, DY1)			\
{																				\
	depths0.x= samp.t.Sample(samp.s, texcoord, int2(-DX0 - 0.5, -DY0 - 0.5)).r;	\
	depths0.y= samp.t.Sample(samp.s, texcoord, int2(-DX1 - 0.5, -DY1 - 0.5)).r;	\
	depths0.z= samp.t.Sample(samp.s, texcoord, int2(-DY0 - 0.5, +DX0 - 0.5)).r;	\
	depths0.w= samp.t.Sample(samp.s, texcoord, int2(-DY1 - 0.5, +DX1 - 0.5)).r;	\
																				\
	depths1.x= samp.t.Sample(samp.s, texcoord, int2(+DX0 - 0.5, +DY0 - 0.5)).r;	\
	depths1.y= samp.t.Sample(samp.s, texcoord, int2(+DX1 - 0.5, +DY1 - 0.5)).r;	\
	depths1.z= samp.t.Sample(samp.s, texcoord, int2(+DY0 - 0.5, -DX0 - 0.5)).r;	\
	depths1.w= samp.t.Sample(samp.s, texcoord, int2(+DY1 - 0.5, -DX1 - 0.5)).r;	\
																				\
	fix_depth(depths0);															\
	fix_depth(depths1);															\
																				\
	occlusion+= calc_occlusion_samples(depths0, depths1, center_depth);			\
}

#define CALC_OCCLUSION4(samp, fix_depth,		DX0, DY0)					\
{																			\
	depths0= samp.t.Sample(samp.s, texcoord, int2(-DX0 - 0.5, -DY0 - 0.5));	\
	depths1= samp.t.Sample(samp.s, texcoord, int2(+DX0 - 0.5, +DY0 - 0.5));	\
	occlusion+= calc_occlusion_samples(depths0, depths1, center_depth);		\
																			\
	depths0= samp.t.Sample(samp.s, texcoord, int2(-DY0 - 0.5, +DX0 - 0.5));	\
	depths1= samp.t.Sample(samp.s, texcoord, int2(+DY0 - 0.5, -DX0 - 0.5)); \
	occlusion+= calc_occlusion_samples(depths0, depths1, center_depth);		\
}

#endif


// small 24-sample

//[maxtempreg(4)]
float4 default_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else

	float2 texcoord= IN.texcoord;

	float inv_center_depth;
#ifdef xenon
	asm
	{
		tfetch2D	inv_center_depth.r___, texcoord, depth_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +0.0, OffsetY= +0.0
	};
#elif DX_VERSION == 11
	inv_center_depth= sample2D(depth_sampler, texcoord).r;
#endif

	inv_center_depth=	(local_depth_constants.x + inv_center_depth * local_depth_constants.y);
	float center_depth=	1.0f / inv_center_depth;


	float4 depths0;
	float4 depths1;
	float occlusion= 0;

//	CALC_OCCLUSION(depth_sampler,	fix_depth_deproject,		1.0, 1.0,		1.0, 0.0);
	CALC_OCCLUSION(depth_sampler,	fix_depth_deproject,		2.0, 2.0,		3.0, 0.0);
	CALC_OCCLUSION(depth_sampler,	fix_depth_deproject,		5.0, 2.0,		2.0, 5.0);
	CALC_OCCLUSION(depth_sampler,	fix_depth_deproject,		7.0, 0.0,		5.0, 5.0);
//	CALC_OCCLUSION(depth_sampler,	fix_depth_deproject,		7.0, 3.0,		3.0, 7.0);

//	return 0.2f + 0.8f * exp2(-0.1f * occlusion*occlusion);

	float fade= calculate_fade(center_depth);

	return CHANNEL_OFFSET + CHANNEL_SCALE * max(1-fade, exp2(CURVE_SIGMA * occlusion*occlusion));


#endif
}


// large 64 sample

//[maxtempreg(4)]
float4 albedo_ps(screen_output IN,	SCREEN_POSITION_INPUT(vpos)) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else

	float2 texcoord= IN.texcoord;

	float inv_center_depth;
#ifdef xenon
	asm
	{
		tfetch2D	inv_center_depth.r___, texcoord, depth_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +0.0, OffsetY= +0.0
	};
#elif DX_VERSION == 11
	inv_center_depth= sample2D(depth_sampler, texcoord).r;
#endif

	inv_center_depth=	(local_depth_constants.x + inv_center_depth * local_depth_constants.y);
	float center_depth=	1.0f / inv_center_depth;

	float4 depths0;
	float4 depths1;
	float occlusion= 0;

//	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			2.0, 2.0);
//	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			3.0, 0.0);

	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			1.5, 1.5);
	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			3.0, 0.0);

	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			5.0, 1.5);
	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			1.5, 5.0);

//	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			4.5, 1.5);
//	CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			1.5, 4.5);

//	occlusion *= 2.0f;			// 8 sample
//	occlusion *= 1.333f;		// 12 sample

//	return 0.08f + 0.92f * exp2(-0.018f * occlusion*occlusion);
//	return 0.1f + 0.9f * exp2(-0.018f * occlusion*occlusion);

	float fade= calculate_fade(center_depth);

	return CHANNEL_OFFSET + CHANNEL_SCALE * max(1-fade, exp2(CURVE_SIGMA * occlusion*occlusion));

#endif
}


// optimized predicated 64 sample

[maxtempreg(5)]
float4 static_sh_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else
	float2 texcoord = IN.texcoord;

	//	float mask;
	//	asm
	//	{
	//		tfetch2D	mask.r___, texcoord, mask_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +0.0, OffsetY= +0.0
	//	};

	float occlusion = 0.0f;
	float fade = 1.0f;

	//	[predicateBlock]
	//	if (mask > 0.0f)
	{
		float inv_center_depth;
#ifdef xenon
		asm
		{
			tfetch2D	inv_center_depth.r___, texcoord, depth_sampler, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX = +0.0, OffsetY = +0.0
		};
#elif DX_VERSION == 11
		inv_center_depth = sample2D(depth_sampler, texcoord).r;
#endif

		inv_center_depth = (local_depth_constants.x + inv_center_depth * local_depth_constants.y);
		float center_depth = 1.0f / inv_center_depth;

		fade = calculate_fade(center_depth);

		float4 depths0;
		float4 depths1;

		CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			3.5, 2.0);
		CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			2.0, 4.0);

		// this if causes more ghosting around edges, but is a big perf win.   I wish we could afford to leave it out  :(
		if (occlusion > 1.0f)
		{
			CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			1.0, 1.5);
			CALC_OCCLUSION4(depth_low_sampler,	fix_depth_scale,			0.0, 2.5);
		}

	}

	//	return 0.25f + 0.75f * exp2(-0.018f * occlusion*occlusion);
	float4 result = CHANNEL_OFFSET + CHANNEL_SCALE * max(1 - fade, exp2(CURVE_SIGMA * occlusion*occlusion));
	//	clip(0.98f - min(result.r, result.a));		// for pixel stats
		return result;
	#endif
}


// screenshot version

float4 shadow_generate_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else

	float2 texcoord= IN.texcoord;

	float occlusion=	0.0f;
	float fade=			1.0f;
	float sample_count=	0.0f;

	{
		float inv_center_depth;
#ifdef xenon
		asm
		{
			tfetch2D	inv_center_depth.r___, texcoord, depth_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +0.0, OffsetY= +0.0
		};
#elif DX_VERSION == 11
		inv_center_depth= sample2D(depth_sampler, texcoord).r;
#endif

		inv_center_depth=	(local_depth_constants.x + inv_center_depth * local_depth_constants.y);
		float center_depth=	1.0f / inv_center_depth;

		fade= calculate_fade(center_depth);

		for (float y= 1; y <= SCREENSHOT_RADIUS_Y; y++)				// don't include zero, (when mirrored, this produces a full sampling of the square, minus the center pixel)
		{
			float relative_y=			y / SCREENSHOT_RADIUS_Y;
			float relative_y_squared=	relative_y * relative_y;

			float x_start=	(y % 2);								// we don't sample every pixel, we sample every other one in a checkerboard pattern

			for (float x= x_start; x <= SCREENSHOT_RADIUS_X; x += 2)
			{
				float relative_x=		x / SCREENSHOT_RADIUS_X;
				float distance_squared=	(relative_x * relative_x + relative_y_squared);

				if (distance_squared <= 1.0f)
				{
					float4 depths0;
					float4 depths1;
					{
#ifdef xenon
						[isolate]
#endif
						float2 offset0=		texcoord + pixel_size.xy * float2( x,  y);
						float2 offset1=		texcoord + pixel_size.xy * float2(-x, -y);
#ifdef xenon
						asm
						{
							tfetch2D	depths0.rgba, offset0, depth_low_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled
							tfetch2D	depths1.rgba, offset1, depth_low_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled
						};
#elif DX_VERSION == 11
						depths0= sample2D(depth_low_sampler, offset0);
						depths1= sample2D(depth_low_sampler, offset1);
#endif
					}
					occlusion	+=	calc_occlusion_samples(depths0.xyzw, depths1.xyzw, center_depth);
					sample_count+=	8.0f;
					{
#ifdef xenon
						[isolate]
#endif
						float2 offset0=		texcoord + pixel_size.xy * float2(-x,  y);
						float2 offset1=		texcoord + pixel_size.xy * float2( x, -y);
#ifdef xenon
						asm
						{
							tfetch2D	depths0.rgba, offset0, depth_low_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled
							tfetch2D	depths1.rgba, offset1, depth_low_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled
						};
#elif DX_VERSION == 11
						depths0= sample2D(depth_low_sampler, offset0);
						depths1= sample2D(depth_low_sampler, offset1);
#endif
					}
					occlusion	+=	calc_occlusion_samples(depths0.xyzw, depths1.xyzw, center_depth);
					sample_count+=	8.0f;
				}
			}
		}
	}

	occlusion /= sample_count;

	return CHANNEL_OFFSET + CHANNEL_SCALE * max(1-fade, exp2(CURVE_SIGMA2 * occlusion*occlusion));
#endif
}


// mask debug
float4 active_camo_ps(screen_output IN) : SV_Target
{
	return 0.0f;
}

[maxtempreg(5)]
float4 static_nv_sh_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else
	float2 texcoord = IN.texcoord;

	//	float mask;
	//	asm
	//	{
	//		tfetch2D	mask.r___, texcoord, mask_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= +0.0, OffsetY= +0.0
	//	};

	float occlusion = 0.0f;
	float fade = 1.0f;

	//	[predicateBlock]
	//	if (mask > 0.0f)
	{
		float inv_center_depth;
#ifdef xenon
		asm
		{
			tfetch2D	inv_center_depth.r___, texcoord, depth_sampler, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled, OffsetX = +0.0, OffsetY = +0.0
		};
#elif DX_VERSION == 11
		inv_center_depth = sample2D(depth_sampler, texcoord).r;
#endif

		inv_center_depth = (local_depth_constants.x + inv_center_depth * local_depth_constants.y);
		float center_depth = 1.0f / inv_center_depth;

		fade = calculate_fade(center_depth);

		float sample_a;
		float sample_b;
		sample_a = sample2D(depth_low_sampler, texcoord + float2(-pixel_size.x, 0.f)).r;
		sample_b = sample2D(depth_low_sampler, texcoord + float2(pixel_size.x, 0.f)).r;
		float ddx = (sample_b - sample_a) * 0.5f;

		sample_a = sample2D(depth_low_sampler, texcoord + float2(0.f, -pixel_size.y)).r;
		sample_b = sample2D(depth_low_sampler, texcoord + float2(0.f, pixel_size.y)).r;
		float ddy = (sample_b - sample_a) * 0.5f;

		float2 depth_gradient = float2(ddx, ddy);

		float depth_dir = dot(depth_gradient, float2(1.f, 0.f)) > 0.f ? 0.5 : -0.5;

		float4 depths0;
		float4 depths1;

		float2 offset;

		offset = float2(3.5f, 2.f);
		depths0 = sample2D(depth_low_sampler, texcoord + (-offset.xy + depth_dir.xx) * pixel_size.xy);
		depths1 = sample2D(depth_low_sampler, texcoord + (offset.xy + depth_dir.xx) * pixel_size.xy);
		occlusion += calc_occlusion_samples(depths0, depths1, center_depth);

		depths0 = sample2D(depth_low_sampler, texcoord + (offset.yx * float2(-1.f, 1.f) + depth_dir.xx) * pixel_size.xy);
		depths1 = sample2D(depth_low_sampler, texcoord + (offset.yx * float2(1.f, -1.f) + depth_dir.xx) * pixel_size.xy);
		occlusion += calc_occlusion_samples(depths0, depths1, center_depth);

		offset = float2(2.0f, 4.f);
		depths0 = sample2D(depth_low_sampler, texcoord + (-offset.xy + depth_dir.xx) * pixel_size.xy);
		depths1 = sample2D(depth_low_sampler, texcoord + (offset.xy + depth_dir.xx) * pixel_size.xy);
		occlusion += calc_occlusion_samples(depths0, depths1, center_depth);

		depths0 = sample2D(depth_low_sampler, texcoord + (offset.yx * float2(-1.f, 1.f) + depth_dir.xx) * pixel_size.xy);
		depths1 = sample2D(depth_low_sampler, texcoord + (offset.yx * float2(1.f, -1.f) + depth_dir.xx) * pixel_size.xy);
		occlusion += calc_occlusion_samples(depths0, depths1, center_depth);

		// this if causes more ghosting around edges, but is a big perf win.   I wish we could afford to leave it out  :(
		if (occlusion > 1.0f)
		{
			offset = float2(1.0f, 1.5f);
			depths0 = sample2D(depth_low_sampler, texcoord + (-offset.xy + depth_dir.xx) * pixel_size.xy);
			depths1 = sample2D(depth_low_sampler, texcoord + (offset.xy + depth_dir.xx) * pixel_size.xy);
			occlusion += calc_occlusion_samples(depths0, depths1, center_depth);

			offset = float2(0.f, 2.5f);
			depths0 = sample2D(depth_low_sampler, texcoord + (-offset.xy + depth_dir.xx) * pixel_size.xy);
			depths1 = sample2D(depth_low_sampler, texcoord + (offset.xy + depth_dir.xx) * pixel_size.xy);
			occlusion += calc_occlusion_samples(depths0, depths1, center_depth);
		}
	}

	//	return 0.25f + 0.75f * exp2(-0.018f * occlusion*occlusion);
	float4 result = CHANNEL_OFFSET + CHANNEL_SCALE * max(1 - fade, exp2(CURVE_SIGMA * occlusion*occlusion));
	//	clip(0.98f - min(result.r, result.a));		// for pixel stats
	return result;
	#endif
}
