//#line 2 "source\rasterizer\hlsl\cubemap_divide.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "explicit\cubemap_registers.fx"

//@generate screen

LOCAL_SAMPLER_CUBE(source_sampler, 0);
LOCAL_SAMPLER_CUBE(divide_sampler, 1);

struct screen_output
{
	float4 position	:SV_Position;
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
	return sampleCUBE(source_sampler, direction);
}

float4 sample_divide_map(float3 direction)
{
	direction.y= -direction.y;
	return sampleCUBE(divide_sampler, direction);
}

float4 default_ps(screen_output IN) : SV_Target
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
