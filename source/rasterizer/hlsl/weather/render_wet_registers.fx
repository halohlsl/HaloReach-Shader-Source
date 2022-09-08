#if DX_VERSION == 9

// shader constants define, please refer to weather\render_wet.cpp
VERTEX_CONSTANT(float4, k_vs_player_view_constant, c250);

PIXEL_CONSTANT(float4x4, k_ps_view_xform_inverse, c213);
PIXEL_CONSTANT(float4,	k_ps_camera_position_and_wet_coeff, c217);  // xyz camera position, w, wet coeff
PIXEL_CONSTANT(float4,	k_ps_ripple_scroll_coeff, c218);  // time, cubemap_blend_factor, , ,

sampler k_ps_wet_sampler_depth_buffer : register(s1);
sampler k_ps_wet_sampler_normal_buffer : register(s2);
sampler k_ps_wet_sampler_cubemap_0 : register(s3);
sampler k_ps_wet_sampler_cubemap_1 : register(s4);
sampler k_ps_wet_sampler_ripple : register(s5);

#elif DX_VERSION == 11

CBUFFER_BEGIN(RenderWetVS)
	CBUFFER_CONST(RenderWetVS,	float4, 	k_vs_player_view_constant,	 			k_vs_render_wet_player_view_constant)
CBUFFER_END

CBUFFER_BEGIN(RenderWetPS)
	CBUFFER_CONST(RenderWetPS,	float4x4,	k_ps_view_xform_inverse,				k_ps_render_wet_view_xform_inverse)
	CBUFFER_CONST(RenderWetPS,	float4,		k_ps_camera_position_and_wet_coeff,		k_ps_render_wet_camera_positiop_and_wet_coeff)
	CBUFFER_CONST(RenderWetPS,	float4,		k_ps_ripple_scroll_coeff,				k_ps_render_wet_ripple_scroll_coeff)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,		k_ps_wet_sampler_depth_buffer,		k_ps_wet_sampler_depth_buffer,		1);
PIXEL_TEXTURE_AND_SAMPLER(_2D,		k_ps_wet_sampler_normal_buffer,		k_ps_wet_sampler_normal_buffer,		2);
PIXEL_TEXTURE_AND_SAMPLER(_CUBE,	k_ps_wet_sampler_cubemap_0,			k_ps_wet_sampler_cubemap_0,			3);
PIXEL_TEXTURE_AND_SAMPLER(_CUBE,	k_ps_wet_sampler_cubemap_1,			k_ps_wet_sampler_cubemap_1,			4);
PIXEL_TEXTURE_AND_SAMPLER(_3D,		k_ps_wet_sampler_ripple,			k_ps_wet_sampler_ripple,			5);

#endif
