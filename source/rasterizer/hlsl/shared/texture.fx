//#line 2 "source\rasterizer\hlsl\texture.fx"
#ifndef __TEXTURE_FX
#define __TEXTURE_FX


#ifdef pc
float4 tex2D_offset_exact(texture_sampler_2d s, const float2 texc, const float offsetx, const float offsety)
{
	return sample2D(s, texc + float2(offsetx, offsety) * pixel_size.xy);
}
#else
#ifdef PIXEL_SIZE
float4 tex2D_offset_exact(texture_sampler_2d s, const float2 texc, const float offsetx, const float offsety)
{
	return sample2D(s, texc + float2(offsetx, offsety) * pixel_size.xy);
}
#endif
#endif

float4 tex2D_offset(texture_sampler_2d s, float2 texc, const float offsetx, const float offsety)
{
	float4 value= 0.0f;
#ifdef pc
	value= tex2D_offset_exact(s, texc, offsetx, offsety);
#else
#ifndef VERTEX_SHADER
	asm {
		tfetch2D value, texc, s, MinFilter=linear, MagFilter=linear, OffsetX=offsetx, OffsetY=offsety
	};
#endif
#endif
	return value;
}


float4 tex2D_offset_point(texture_sampler_2d s, float2 texc, const float offsetx, const float offsety)
{
	float4 value= 0.0f;
#ifdef pc
	value= tex2D_offset_exact(s, texc, offsetx, offsety);
#else
#ifndef VERTEX_SHADER
	asm {
		tfetch2D value, texc, s, MinFilter=point, MagFilter=point, OffsetX=offsetx, OffsetY=offsety
	};
#endif
#endif
	return value;
}

float4 calculate_weights_bicubic(float4 dist)
{
	//
	//  bicubic is a smooth sampling method
	//  it is smoother than bilinear, but can have ringing around high-contrast edges (because of it's weights can go negative)
	//	bicubic in linear space is not the best..
	//

	// input vector contains the distance of 4 sample pixels [-1.5, -0.5, +0.5, +1.5] to our sample point
	// output vector contains the weights for each of the corresponding pixels

	// bicubic parameter 'A'
#define A -0.75f

	float4 weights;
	weights.yz= (((A + 2.0f) * dist.yz - (A + 3.0f)) * dist.yz * dist.yz + 1.0f);					// 'photoshop' style bicubic
	weights.xw= (((A * dist.xw - 5.0f * A ) * dist.xw + 8.0f * A ) * dist.xw - 4.0f * A);
	return weights;
}

float4 calculate_weights_bspline(float4 dist)
{
	//
	//  bspline is a super-smooth sampling method
	//  it is smoother than bicubic (much smoother than bilinear)
	//  and, unlike bicubic, is guaranteed not to have ringing around high-contrast edges (because it has no negative weights)
	//  the downside is it gives everything a slight blur so you lose a bit of the high frequencies
	//

	float4 weights;
	weights.yz= (4.0f + (-6.0f + 3.0f * dist.yz) * dist.yz * dist.yz) / 6.0f;						// bspline
	weights.xw= (2.0f - dist.xw) * (2.0f - dist.xw) * (2.0f - dist.xw) / 6.0f;
	return weights;
}

float4 calculate_weights_bspline_2x(float dist)
{
	// these weights only work when you're resizing by a perfect factor of two.  (but it's faster than above)

	// 0, 0.5
//	return	float4( 0.166666,  0.666666,  0.166666, 0.0) +
//			float4(-0.291666, -0.375000,  0.625000, 0.041666667) * dist;

	// 0.5, 1.0
	return	float4( 0.0416666,  0.791666,  0.291666, -0.125000) +
			float4(-0.0416666, -0.625000,  0.375000,  0.291666) * dist;
}


#ifndef pc
#define DECLARE_TEX2D_4x4_METHOD(name, calculate_weights_func)																\
float4 name(texture_sampler_2d s, float2 texc)																						\
{																															\
    float4 subpixel_dist;																									\
    asm {																													\
        getWeights2D subpixel_dist, texc, s																					\
    };																														\
  	float4 x_dist= float4(1.0f+subpixel_dist.x, subpixel_dist.x, 1.0f-subpixel_dist.x, 2.0f-subpixel_dist.x);				\
	float4 x_weights= calculate_weights_func(x_dist);																		\
																															\
	float4 y_dist= float4(1.0f+subpixel_dist.y, subpixel_dist.y, 1.0f-subpixel_dist.y, 2.0f-subpixel_dist.y);				\
	float4 y_weights= calculate_weights_func(y_dist);																		\
																															\
	float4 color=	0.0f;																									\
																															\
	[unroll]																												\
	[isolate]																												\
	for (int y= 0; y < 4; y++)																								\
	{																														\
		float y_offset= y - 1.5f;																							\
		float4 color0, color1, color2, color3;																				\
		asm {																												\
			tfetch2D color0, texc, s, MinFilter=point, MagFilter=point, OffsetX=-1.5, OffsetY=y_offset						\
			tfetch2D color1, texc, s, MinFilter=point, MagFilter=point, OffsetX=-0.5, OffsetY=y_offset						\
			tfetch2D color2, texc, s, MinFilter=point, MagFilter=point, OffsetX=+0.5, OffsetY=y_offset						\
			tfetch2D color3, texc, s, MinFilter=point, MagFilter=point, OffsetX=+1.5, OffsetY=y_offset						\
		};																													\
		float4 vert_color=	x_weights.x * color0 +																			\
							x_weights.y * color1 +																			\
							x_weights.z * color2 +																			\
							x_weights.w * color3;																			\
																															\
		color += vert_color * y_weights.x;																					\
		y_weights.xyz= y_weights.yzw;																						\
	}																														\
																															\
	return color;																											\
}
#elif DX_VERSION == 11
#define DECLARE_TEX2D_4x4_METHOD(name, calculate_weights_func)															\
float4 name(texture_sampler_2d s, float2 texc)																				\
{																															\
    float2 subpixel_dist;																									\
	uint width,height;																										\
	s.t.GetDimensions(width, height);																						\
	subpixel_dist = frac(texc * float2(width, height));																		\
  	float4 x_dist= float4(1.0f+subpixel_dist.x, subpixel_dist.x, 1.0f-subpixel_dist.x, 2.0f-subpixel_dist.x);				\
	float4 x_weights= calculate_weights_func(x_dist);																		\
																															\
	float4 y_dist= float4(1.0f+subpixel_dist.y, subpixel_dist.y, 1.0f-subpixel_dist.y, 2.0f-subpixel_dist.y);				\
	float4 y_weights= calculate_weights_func(y_dist);																		\
																															\
	float4 color=	0.0f;																									\
																															\
	for (int y= 0; y < 4; y++)																								\
	{																														\
		int y_offset= y - 2;																								\
		float4 color0, color1, color2, color3;																				\
		color0 = s.t.Sample(s.s, texc, int2(-2, y_offset));																	\
		color1 = s.t.Sample(s.s, texc, int2(-1, y_offset));																	\
		color2 = s.t.Sample(s.s, texc, int2(0, y_offset));																	\
		color3 = s.t.Sample(s.s, texc, int2(1, y_offset));																	\
		float4 vert_color=	x_weights.x * color0 +																				\
						x_weights.y * color1 +																				\
						x_weights.z * color2 +																				\
						x_weights.w * color3;																				\
		color += vert_color * y_weights.x;																					\
		y_weights.xyz= y_weights.yzw;																						\
	}																														\
																															\
	return color;																											\
}
#else  // pc
#define DECLARE_TEX2D_4x4_METHOD(name, calculate_weights_func) float4 name(texture_sampler_2d s, float2 texc) { return 0.0f; }
#endif // pc

DECLARE_TEX2D_4x4_METHOD(tex2D_bspline, calculate_weights_bspline)
DECLARE_TEX2D_4x4_METHOD(tex2D_bicubic, calculate_weights_bicubic)


float4 tex2D_bspline_fast_2x(sampler2D s, float2 texc)
{
/*
	float4 subpixel_dist;
	asm
	{
		getWeights2D subpixel_dist, texc, s
	};

	// force subpixel to be 0.5 or 1
	subpixel_dist.xy= (floor(subpixel_dist.xy * 2.0f + 0.5f) * 0.5f);

	// calculate offsets	(p0.x, p0.y, p1.x, p1.y) in pixels
	float4 offsets= float4(-0.083333, -0.083333,  0.883333,  0.883333) +
					float4(-0.916666, -0.916666, -0.683333, -0.683333) * subpixel_dist.xyxy;

	// calculate weights	(p0.x, p0.y, p1.x, p1.y)
	float4 weights= float4( 0.833333,  0.833333,  0.166666,  0.166666) +
					float4(-0.666666, -0.666666,  0.666666,  0.666666) * subpixel_dist.xyxy;

	// convert offsets to texcoords
	offsets *= pixel_size.xyxy;

	float4 color= 0.0f;

	color += tex2D(s, texc + offsets.xy) * weights.x * weights.y;
	color += tex2D(s, texc + offsets.xw) * weights.x * weights.w;
	color += tex2D(s, texc + offsets.zy) * weights.z * weights.y;
	color += tex2D(s, texc + offsets.zw) * weights.z * weights.w;

	return color;
*/
}


#endif // __TEXTURE_FX