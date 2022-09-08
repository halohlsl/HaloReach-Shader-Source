#if DX_VERSION == 9

sampler		splash_texture : register(s0);
sampler		depth_texture : register(s1);


float4x4	texcoord_to_world : register(c100);

#elif DX_VERSION == 11

PIXEL_TEXTURE_AND_SAMPLER(_2D_ARRAY,	splash_texture,		k_ps_splash_ripples_splash_texture,		0)
PIXEL_TEXTURE_AND_SAMPLER(_2D,			depth_texture,		k_ps_splash_ripples_depth_texture,		1)

CBUFFER_BEGIN(SplashRipplesPS)
	CBUFFER_CONST(SplashRipplesPS,		float4x4,	texcoord_to_world,	k_ps_splash_ripples_texcoord_to_world)
CBUFFER_END

#endif
