//#line 2 "source\rasterizer\hlsl\yuv_to_rgb.hlsl"

#include "hlsl_vertex_types.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler tex0   : register(s0);
sampler tex1   : register(s1);
sampler tex2   : register(s2);
sampler tex3   : register(s3);
PIXEL_CONSTANT(float4, tor   ,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);
PIXEL_CONSTANT(float4, tog   ,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_1);
PIXEL_CONSTANT(float4, tob   ,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_2);
PIXEL_CONSTANT(float4, consts,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_3);

float4 default_ps(screen_output IN) : COLOR
{                               
	float4 c;                   
	float4 p;                   
	c.x = tex2D( tex0, IN.texcoord ).x;
	c.y = tex2D( tex1, IN.texcoord ).x;
	c.z = tex2D( tex2, IN.texcoord ).x;
	c.w = consts.x;
	p.w = tex2D( tex3, IN.texcoord ).x;
	p.x = dot( tor, c );
	p.y = dot( tog, c );
	p.z = dot( tob, c );
	p.w*= consts.w;
	return p;
}
