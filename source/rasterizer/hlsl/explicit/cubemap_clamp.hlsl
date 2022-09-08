#line 2 "source\rasterizer\hlsl\cubemap_clamp.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
//@generate screen

#include "explicit\cubemap_registers.fx"

LOCAL_SAMPLER_CUBE(source_sampler, 0);

struct screen_output
{
	float4 position	:SV_POSITION;
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

float4 default_ps(screen_output IN) : SV_Target
{
	float2 sample0= IN.texcoord;

	float3 direction;
	direction= forward - (sample0.y*2-1)*up - (sample0.x*2-1)*left;
	direction= direction * (1.0 / sqrt(dot(direction, direction)));

 	float4 color= sample_cube_map(direction);

	color.rgb= ((isnan(color.rgb) || any(color.rgb < 0)) ? 0.0f : isinf(color.rgb) ? scale.rgb : min(color.rgb, scale.rgb));		// if it's NAN, replace with zero, if it's INF, replace with max, otherwise, clamp

 	return color;
}
