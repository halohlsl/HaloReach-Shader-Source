#if DX_VERSION == 9

#ifdef VERTEX_SHADER
sampler2D	data_texture : register(s0);
float4		g_read_transform : register(c100);
#endif

#ifdef PIXEL_SHADER
sampler2D	splash_texture : register(s0);
float4 g_color : register(c100);
#endif

#elif DX_VERSION == 11

CBUFFER_BEGIN(RenderLightningVS)
	CBUFFER_CONST(RenderLightningVS,	float4,		g_read_transform,		k_vs_render_lightning_read_transform)
CBUFFER_END

BUFFER(g_lightning_buffer, k_vs_render_lightning_buffer, float4, 0);

CBUFFER_BEGIN(RenderLightningPS)
	CBUFFER_CONST(RenderLightningPS,	float4,		g_color,				k_ps_render_lightning_color)
CBUFFER_END

PIXEL_TEXTURE_AND_SAMPLER(_2D,	splash_texture,		k_ps_render_lightning_splash_textuure,	0)

#endif
