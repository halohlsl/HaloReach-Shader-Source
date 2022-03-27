//#line 2 "source\rasterizer\hlsl\cubemap_divide.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
//@generate screen

samplerCUBE source_sampler : register(s0);
samplerCUBE divide_sampler : register(s1);

// source texture size (width, height)
PIXEL_CONSTANT(float2, source_size, c0);
PIXEL_CONSTANT(float3, forward, c1);
PIXEL_CONSTANT(float3, up, c2);
PIXEL_CONSTANT(float3, left, c3);
PIXEL_CONSTANT(float4, scale, c4);

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

float4 sample_cube_map(float3 direction)
{
	direction.y= -direction.y;
	return texCUBE(source_sampler, direction);
}

float4 sample_divide_map(float3 direction)
{
	direction.y= -direction.y;
	return texCUBE(divide_sampler, direction);
}

float4 default_ps(screen_output IN) : COLOR
{
	float2 sample0= IN.texcoord;
	
	float3 direction;
	direction= forward - (sample0.y*2-1)*up - (sample0.x*2-1)*left;
	direction= direction * (1.0 / sqrt(dot(direction, direction)));

 	float4 color= sample_cube_map(direction);
 	float4 divide= sample_divide_map(direction);
 	
 	color /= max(divide, 0.000006);
 	
 	color= ((isnan(color) || isinf(color)) ? 0.0f : color);		// if it's INF or NAN, replace with zero
 	 	
	return color * scale;
}
