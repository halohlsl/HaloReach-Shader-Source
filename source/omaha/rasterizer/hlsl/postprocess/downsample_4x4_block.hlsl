//#line 2 "source\rasterizer\hlsl\downsample_4x4_block.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen
//@entry default
//@entry linear_depth_downsample

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
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

screen_output linear_depth_downsample_vs(in vertex_type IN)
{
	return default_vs(IN);
}

float4 linear_depth_downsample_ps(screen_output IN) : SV_Target
{
	float4 depth= 0.f;

	depth = tex2D_offset(source_sampler, IN.texcoord, -1, -1);
	depth = min(depth, tex2D_offset(source_sampler, IN.texcoord, +1, -1));
	depth = min(depth, tex2D_offset(source_sampler, IN.texcoord, -1, +1));
	depth = min(depth, tex2D_offset(source_sampler, IN.texcoord, +1, +1));

	return depth;
}
