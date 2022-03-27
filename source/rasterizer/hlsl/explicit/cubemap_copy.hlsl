//#line 1 "source\rasterizer\hlsl\cubemap_copy.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"

//@generate screen

samplerCUBE source_sampler : register(s0);

// source texture size (width, height)
PIXEL_CONSTANT(float2, source_size, c0);
PIXEL_CONSTANT(float3, forward, c1);
PIXEL_CONSTANT(float3, up, c2);
PIXEL_CONSTANT(float3, left, c3);
PIXEL_CONSTANT(float4, exposure, c4);

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

float4 default_ps(screen_output IN) : COLOR
{
	float2 texcoord= IN.texcoord;
	
	float3 direction= forward - (texcoord.y*2-1)*up - (texcoord.x*2-1)*left;

	float4 color= exposure * sample_cube_map(direction);

	return color;
}
