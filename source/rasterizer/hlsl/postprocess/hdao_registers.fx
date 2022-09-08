#if DX_VERSION == 9

VERTEX_CONSTANT(float4, quad_tiling,		c16);		// quad tiling parameters (x, 1/x, y, 1/y)
VERTEX_CONSTANT(float4, position_transform, c17);		// position transform from quad coordinates [0,x], [0,y] -> screen coordinates
VERTEX_CONSTANT(float4, texture_transform,	c18);		// texture transform from quad coordinates [0,x], [0,y] -> texture coordinates
VERTEX_CONSTANT(float4, depth,	c19);					// depth at which the output should be located

PIXEL_CONSTANT( float4, pixel_size,				POSTPROCESS_PIXELSIZE_PIXEL_CONSTANT );
PIXEL_CONSTANT( float4, scale,					POSTPROCESS_DEFAULT_PIXEL_CONSTANT );
PIXEL_CONSTANT( float4, local_depth_constants,	c100 );		// ###ctchou $TODO is this the same as the global depth constants?
PIXEL_CONSTANT( float4,	corner_params,		c116 );			// corner_scale, corner_scale*2, corner_offset
PIXEL_CONSTANT( float4,	bounds_params,		c117 );			// bounds_scale, bounds_offset
PIXEL_CONSTANT( float4,	curve_params,		c118 );			// curve_scale, curve_offset, curve_sigma
PIXEL_CONSTANT( float4,	fade_params,		c119 );			//
PIXEL_CONSTANT( float4, channel_scale,		c120 );			// channel transform CONTAINS curve_scale/curve_offset already
PIXEL_CONSTANT( float4, channel_offset,		c121 );

sampler2D depth_sampler		: register(s0);
sampler2D depth_low_sampler : register(s1);
sampler2D mask_sampler		: register(s2);

#elif DX_VERSION == 11

CBUFFER_BEGIN(HDAOVS)
	CBUFFER_CONST(HDAOVS,	float4, 	quad_tiling,				k_vs_hdao_quad_tiling)
	CBUFFER_CONST(HDAOVS,	float4, 	position_transform, 		k_vs_hdao_position_transform)
	CBUFFER_CONST(HDAOVS,	float4, 	texture_transform,			k_vs_hdao_texture_transform)
	CBUFFER_CONST(HDAOVS,	float4, 	depth,						k_vs_hdao_depth)
CBUFFER_END

CBUFFER_BEGIN(HDAOPS)
	CBUFFER_CONST(HDAOPS,	float4,		pixel_size,					k_ps_hdao_pixel_size)
	CBUFFER_CONST(HDAOPS,	float4,		scale,						k_ps_hdao_scale)
	CBUFFER_CONST(HDAOPS,	float4,		corner_params,				k_ps_hdao_corner_params)
	CBUFFER_CONST(HDAOPS,	float4,		bounds_params,				k_ps_hdao_bounds_params)
	CBUFFER_CONST(HDAOPS,	float4,		curve_params,				k_ps_hdao_curve_params)
	CBUFFER_CONST(HDAOPS,	float4,		fade_params,				k_ps_hdao_fade_params)
	CBUFFER_CONST(HDAOPS,	float4,		channel_scale,				k_ps_hdao_channel_scale)
	CBUFFER_CONST(HDAOPS,	float4,		channel_offset,				k_ps_hdao_channel_offset)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	depth_sampler,		k_ps_hdao_depth_sampler, 0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	depth_low_sampler,	k_ps_hdao_depth_low_sampler, 1)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	mask_sampler,		k_ps_hdao_mask_sampler, 2)

#endif
