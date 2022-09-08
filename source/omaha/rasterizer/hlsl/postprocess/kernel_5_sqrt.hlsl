//#line 2 "source\rasterizer\hlsl\kernel_5_sqrt.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\kernel_5_registers.fx"
//@generate screen

LOCAL_SAMPLER_2D(target_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
{
	float2 sample= IN.texcoord;

	float4 color=	kernel[0].z * sample2D(target_sampler, sample + kernel[0].xy * pixel_size.xy) +
					kernel[1].z * sample2D(target_sampler, sample + kernel[1].xy * pixel_size.xy) +
					kernel[2].z * sample2D(target_sampler, sample + kernel[2].xy * pixel_size.xy) +
					kernel[3].z * sample2D(target_sampler, sample + kernel[3].xy * pixel_size.xy) +
					kernel[4].z * sample2D(target_sampler, sample + kernel[4].xy * pixel_size.xy);

	return float4(sqrt(color.rgb), color.a) * scale;
}
