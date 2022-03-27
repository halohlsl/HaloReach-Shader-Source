//#line 2 "source\rasterizer\hlsl\downsample_4x4_block.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
	float4 color= 0.0f;

	// this is a 4x4 box filter
	color += tex2D_offset(source_sampler, IN.texcoord, -1, -1);
	color += tex2D_offset(source_sampler, IN.texcoord, +1, -1);
	color += tex2D_offset(source_sampler, IN.texcoord, -1, +1);
	color += tex2D_offset(source_sampler, IN.texcoord, +1, +1);
	color= color / 4.0f;

	return color;
}
