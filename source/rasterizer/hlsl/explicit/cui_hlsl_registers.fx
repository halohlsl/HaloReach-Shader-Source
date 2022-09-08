#ifndef __CUI_HLSL_REGISTERS_FX__
#ifndef DEFINE_CPP_CONSTANTS
#define __CUI_HLSL_REGISTERS_FX__
#endif

//NOTE: if you modify any of this, than you need to modify cui_hlsl_registers.h

#if DX_VERSION == 9

VERTEX_CONSTANT(float4x4, k_cui_vertex_shader_constant_projection_matrix, c30);
VERTEX_CONSTANT(float4x3, k_cui_vertex_shader_constant_model_view_matrix, c34);
VERTEX_CONSTANT(float4, k_cui_vertex_shader_constant0, c37);

PIXEL_CONSTANT(float4, k_cui_pixel_shader_color0, c30);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color1, c31);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color2, c32);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color3, c33);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color4, c34);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color5, c35);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar0, c36);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar1, c37);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar2, c38);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar3, c39);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar4, c40);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar5, c41);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar6, c42);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar7, c43);

PIXEL_CONSTANT(float4, k_cui_pixel_shader_bounds, c44);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_pixel_size, c45);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_tint, c46);

// <scale, offset, bool need_to_premultiply>
// premultiplied (render target): <1, 0, 1>
// non-premultiplied (source bitmap): <-1, 1, 0>
PIXEL_CONSTANT(float4, k_cui_sampler0_transform, c47);
PIXEL_CONSTANT(float4, k_cui_sampler1_transform, c48);

sampler2D source_sampler0 : register(s0);
sampler2D source_sampler1 : register(s1);

#elif DX_VERSION == 11

CBUFFER_BEGIN(CUIVS)
	CBUFFER_CONST(CUIVS,	float4x4, 	k_cui_vertex_shader_constant_projection_matrix, 	k_cui_vertex_shader_constant_projection_matrix)
	CBUFFER_CONST(CUIVS,	float4x3, 	k_cui_vertex_shader_constant_model_view_matrix, 	k_cui_vertex_shader_constant_model_view_matrix)
	CBUFFER_CONST(CUIVS,	float4, 	k_cui_vertex_shader_constant0, 						k_cui_vertex_shader_constant0)
CBUFFER_END

CBUFFER_BEGIN(CUIPS)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color0, 							k_cui_pixel_shader_color0)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color1, 							k_cui_pixel_shader_color1)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color2, 							k_cui_pixel_shader_color2)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color3, 							k_cui_pixel_shader_color3)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color4, 							k_cui_pixel_shader_color4)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_color5, 							k_cui_pixel_shader_color5)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar0,							k_cui_pixel_shader_scalar0)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar0_pad,						k_cui_pixel_shader_scalar0_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar1,							k_cui_pixel_shader_scalar1)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar1_pad,						k_cui_pixel_shader_scalar1_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar2,							k_cui_pixel_shader_scalar2)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar2_pad,						k_cui_pixel_shader_scalar2_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar3,							k_cui_pixel_shader_scalar3)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar3_pad,						k_cui_pixel_shader_scalar3_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar4,							k_cui_pixel_shader_scalar4)
	CBUFFER_CONST(CUIPS,	float3,		k_cui_pixel_shader_scalar4_pad,						k_cui_pixel_shader_scalar4_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar5,							k_cui_pixel_shader_scalar5)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar5_pad,						k_cui_pixel_shader_scalar5_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar6,							k_cui_pixel_shader_scalar6)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar6_pad,						k_cui_pixel_shader_scalar6_pad)
	CBUFFER_CONST(CUIPS,	float, 		k_cui_pixel_shader_scalar7,							k_cui_pixel_shader_scalar7)
	CBUFFER_CONST(CUIPS,	float3, 	k_cui_pixel_shader_scalar7_pad,						k_cui_pixel_shader_scalar7_pad)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_bounds,							k_cui_pixel_shader_texture_bounds)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_pixel_size,						k_cui_pixel_shader_pixel_size)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_pixel_shader_tint,							k_cui_pixel_shader_tint)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_sampler0_transform,							k_cui_pixel_shader_sampler0_transform)
	CBUFFER_CONST(CUIPS,	float4,		k_cui_sampler1_transform,							k_cui_pixel_shader_sampler1_transform)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler0,	k_cui_pixel_shader_source_sampler0,		0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler1,	k_cui_pixel_shader_source_sampler1,		1)

#endif

#endif // __CUI_HLSL_REGISTERS_FX__
