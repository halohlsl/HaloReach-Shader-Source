#ifndef _SCREEN_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _SCREEN_REGISTERS_FX_
#endif

#if DX_VERSION == 9

VERTEX_CONSTANT(float4,		screenspace_to_pixelspace_xform_vs,	c250)
VERTEX_CONSTANT(float4,		screenspace_xform_vs,				c251)

PIXEL_CONSTANT(float4,		screenspace_xform,					c200)
PIXEL_CONSTANT(float4,		inv_screenspace_xform,				c201)
PIXEL_CONSTANT(float4,		screenspace_to_pixelspace_xform,	c202)
PIXEL_CONSTANT(float4x4,	pixel_to_world_relative,			c204)

#elif DX_VERSION == 11

CBUFFER_BEGIN(ScreenVS)
	CBUFFER_CONST(ScreenVS,		float4,		screenspace_to_pixelspace_xform_vs,		k_vs_screen_screenspace_to_pixel_xform)
	CBUFFER_CONST(ScreenVS,		float4,		screenspace_xform_vs,					k_vs_screen_screenspace_xform)
CBUFFER_END

CBUFFER_BEGIN(ScreenPS)
	CBUFFER_CONST(ScreenPS,		float4,		screenspace_xform,						k_ps_screen_screenspace_xform)
	CBUFFER_CONST(ScreenPS,		float4,		inv_screenspace_xform,					k_ps_screen_inv_screenspace_xform)
	CBUFFER_CONST(ScreenPS,		float4,		screenspace_to_pixelspace_xform,		k_ps_screen_screenspace_to_pixelspace_xform)
	CBUFFER_CONST(ScreenPS,		float4x4,	pixel_to_world_relative,				k_ps_screen_pixel_to_world_relative)
CBUFFER_END

#endif

#endif
