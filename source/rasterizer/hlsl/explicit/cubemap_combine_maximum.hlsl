#line 2 "source\rasterizer\hlsl\cubemap_combine_maximum.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
//@generate screen

samplerCUBE source_a_sampler : register(s0);
samplerCUBE source_b_sampler : register(s1);

// source texture size (width, height)
PIXEL_CONSTANT(float2, source_size, c0);
PIXEL_CONSTANT(float3, forward, c1);
PIXEL_CONSTANT(float3, up, c2);
PIXEL_CONSTANT(float3, left, c3);
PIXEL_CONSTANT(float4, scale_a, c4);
PIXEL_CONSTANT(float4, scale_b, c5);

PIXEL_CONSTANT(float4, weight_slope_a, c6);
PIXEL_CONSTANT(float4, weight_slope_b, c7);
PIXEL_CONSTANT(float4, max_a, c8);
PIXEL_CONSTANT(float4, max_b, c9);

struct screen_output
{
	float4 position	:POSITION;
	float2 texcoord	:TEXCOORD0;
};

screen_output default_vs(vertex_type IN)
{
	screen_output OUT;

	OUT.texcoord = IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;

	return OUT;
}

float4 default_ps(screen_output IN) : COLOR
{
	float2 sample0= IN.texcoord;
	
	float3 direction;
	direction= forward - (sample0.y*2-1)*up - (sample0.x*2-1)*left;
	direction= direction * (1.0 / sqrt(dot(direction, direction)));

	// flip for historical reasons
	direction.y=	-direction.y;

 	float4 a=			texCUBE(source_a_sampler, direction);
 	float4 b=			texCUBE(source_b_sampler, direction);

	float weight_epsilon=	0.001f;
	float bright_falloff=	30.0f;
	float4 a_weight=		saturate(min(a*weight_slope_a + weight_epsilon/scale_a, bright_falloff * (max_a-a)) + weight_epsilon*scale_a);
	float4 b_weight=		saturate(min(b*weight_slope_b + weight_epsilon/scale_b, bright_falloff * (max_b-b)) + weight_epsilon*scale_b);

	float weight_power=		2.0f;
	a_weight=	pow(a_weight, weight_power);
	b_weight=	pow(b_weight, weight_power);

	float4 color=			((a*scale_a)*a_weight + (b*scale_b)*b_weight) / (a_weight + b_weight);
	
// 	float4 color=			max(a*scale_a, b*scale_b);
 	 	
 	color= ((isnan(color) || isinf(color)) ? 0.0f : color);		// if it's INF or NAN, replace with zero
 
	return color;
}
