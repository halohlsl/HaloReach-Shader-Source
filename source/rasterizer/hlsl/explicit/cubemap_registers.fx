#ifndef _CUBEMAP_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _CUBEMAP_REGISTERS_FX_
#endif

#if DX_VERSION == 9

// source texture size (width, height)
PIXEL_CONSTANT(float2, source_size, c0);
PIXEL_CONSTANT(float3, forward, c1);
PIXEL_CONSTANT(float3, up, c2);
PIXEL_CONSTANT(float3, left, c3);
PIXEL_CONSTANT(float4, scale, c4);
PIXEL_CONSTANT(float4, scale_b, c5);

PIXEL_CONSTANT(float4, weight_slope_a, c6);
PIXEL_CONSTANT(float4, weight_slope_b, c7);
PIXEL_CONSTANT(float4, max_a, c8);
PIXEL_CONSTANT(float4, max_b, c9);

PIXEL_CONSTANT(float4, exposure, c4);
PIXEL_CONSTANT(float4, delta, c4);

#elif DX_VERSION == 11

CBUFFER_BEGIN(CubemapPS)
	CBUFFER_CONST(CubemapPS,		float2,		source_size,		k_ps_cubemap_source_size)
	CBUFFER_CONST(CubemapPS,		float2,		source_size_pad,	k_ps_cubemap_source_size_pad)
	CBUFFER_CONST(CubemapPS,		float3,		forward,			k_ps_cubemap_forward)
	CBUFFER_CONST(CubemapPS,		float,		forward_pad,		k_ps_cubemap_forward_pad)
	CBUFFER_CONST(CubemapPS,		float3,		up,					k_ps_cubemap_up)
	CBUFFER_CONST(CubemapPS,		float,		up_pad,				k_ps_cubemap_up_pad)
	CBUFFER_CONST(CubemapPS,		float3,		left,				k_ps_cubemap_left)
	CBUFFER_CONST(CubemapPS,		float,		left_pad,			k_ps_cubemap_left_pad)
	CBUFFER_CONST(CubemapPS,		float4,		scale,				k_ps_cubemap_scale)
	CBUFFER_CONST(CubemapPS,		float4,		scale_b,			k_ps_cubemap_scale_b)
	CBUFFER_CONST(CubemapPS,		float4,		weight_slope_a, 	k_ps_cubemap_weight_slope_a)
	CBUFFER_CONST(CubemapPS,		float4,		weight_slope_b, 	k_ps_cubemap_weight_slope_b)
	CBUFFER_CONST(CubemapPS,		float4,		max_a,				k_ps_cubemap_max_a)
	CBUFFER_CONST(CubemapPS,		float4,		max_b,				k_ps_cubemap_max_b)
CBUFFER_END

#ifndef DEFINE_CPP_CONSTANTS
#define scale_a scale
#define delta scale
#define exposure scale
#else
#define k_ps_cubemap_scale_a k_ps_cubemap_scale
#define k_ps_cubemap_delta k_ps_cubemap_scale
#endif

#endif

#endif
