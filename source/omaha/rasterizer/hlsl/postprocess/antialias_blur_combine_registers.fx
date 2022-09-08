#if DX_VERSION == 9

sampler2D source_sampler0 : register(s0);
sampler2D source_sampler1 : register(s1);

PIXEL_CONSTANT( float4, texcoord_xform0,		POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);
PIXEL_CONSTANT( float4, texcoord_xform1,		POSTPROCESS_EXTRA_PIXEL_CONSTANT_1);


VERTEX_CONSTANT( float4, vs_texcoord_xform0,	c8);
VERTEX_CONSTANT( float4, vs_texcoord_xform1,	c9);

VERTEX_CONSTANT(float4, quad_tiling, c16);				// quad tiling parameters (x, 1/x, y, 1/y)
VERTEX_CONSTANT(float4, position_transform, c17);		// position transform from quad coordinates [0,x], [0,y] -> screen coordinates
VERTEX_CONSTANT(float4, texture_transform, c18);		// texture transform from quad coordinates [0,x], [0,y] -> texture coordinates

#elif DX_VERSION == 11

CBUFFER_BEGIN(AntialiasBlurCombineVS)
	CBUFFER_CONST(AntialiasBlurCombineVS,	float4, 	vs_texcoord_xform0,		k_vs_antialias_blur_combine_texcoord_xform0)
	CBUFFER_CONST(AntialiasBlurCombineVS,	float4, 	vs_texcoord_xform1,		k_vs_antialias_blur_combine_texcoord_xform1)
	CBUFFER_CONST(AntialiasBlurCombineVS,	float4, 	quad_tiling,			k_vs_antialias_blur_combine_quad_tiling)
	CBUFFER_CONST(AntialiasBlurCombineVS,	float4, 	position_transform,		k_vs_antialias_blur_combine_position_transform)
	CBUFFER_CONST(AntialiasBlurCombineVS,	float4, 	texture_transform,		k_vs_antialias_blur_combine_texture_transform)
CBUFFER_END

CBUFFER_BEGIN(AntialiasBlurCombinePS)
	CBUFFER_CONST(AntialiasBlurCombinePS,	float4, 	texcoord_xform0,		k_ps_antialias_blur_combine_texcoord_xform0)
	CBUFFER_CONST(AntialiasBlurCombinePS,	float4, 	texcoord_xform1,		k_ps_antialias_blur_combine_texcoord_xform1)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler0,	k_ps_antialias_blur_combine_source_sampler0,	0);
PIXEL_TEXTURE_AND_SAMPLER(_2D,	source_sampler1,	k_ps_antialias_blur_combine_source_sampler1,	1);

#endif
