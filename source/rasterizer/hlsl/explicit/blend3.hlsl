//#line 2 "source\rasterizer\hlsl\blend3.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D tex0_sampler : register(s0);
sampler2D tex1_sampler : register(s1);
sampler2D tex2_sampler : register(s2);

float4 default_ps(screen_output IN) : COLOR
{
	float4 base_sample= tex2D(tex0_sampler, IN.texcoord);
	float4 star_sample= tex2D(tex0_sampler, IN.texcoord);

	float4 color;
	
	color.rgb=	scale.r * base_sample.rgb +
				scale.g * tex2D(tex1_sampler, IN.texcoord).rgb;
				
	color.a= base_sample.a;
				  
	return color;
}
