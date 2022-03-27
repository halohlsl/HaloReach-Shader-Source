//#line 2 "source\rasterizer\hlsl\bloom_add_alpha1.hlsl"


#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


sampler2D original_sampler : register(s0);
sampler2D add_sampler : register(s1);


float4 default_ps(screen_output IN) : COLOR
{
	float4 original= tex2D(original_sampler, IN.texcoord);
	float4 add= tex2D(add_sampler, IN.texcoord);

	float4 color;
	color.rgb= scale.rgb * original.rgb + add.rgb;
	color.a= 1.0f;
	
	return color;
}
