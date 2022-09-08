//#line 2 "source\rasterizer\hlsl\kernel_5.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\kernel_5_registers.fx"
//@generate screen
//@entry default
//@entry kernel5_non_xenon_output

LOCAL_SAMPLER_2D(target_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
{
	float2 sample= IN.texcoord;

	// Multiply by 2 ^ 3 to match Xenon tex2D data
	float4 color=	kernel[0].z * sample2D(target_sampler, sample + kernel[0].xy * pixel_size.xy) * 8 +
					kernel[1].z * sample2D(target_sampler, sample + kernel[1].xy * pixel_size.xy) * 8 +
					kernel[2].z * sample2D(target_sampler, sample + kernel[2].xy * pixel_size.xy) * 8 +
					kernel[3].z * sample2D(target_sampler, sample + kernel[3].xy * pixel_size.xy) * 8 +
					kernel[4].z * sample2D(target_sampler, sample + kernel[4].xy * pixel_size.xy) * 8;

	color = color * scale;

	// The output surface/texture on Xenon has a range of 0-8 and an additional exponent bias of -2
	color = min(color * 4, 8); // like in Xenon render-target
	color = color / 32; // like in Xenon "Resolve" texture

	return color;
}

screen_output kernel5_non_xenon_output_vs(in vertex_type IN)
{
	return default_vs(IN);
}

float4 kernel5_non_xenon_output_ps(screen_output IN): SV_Target
{
	float2 texcoord = IN.texcoord;

	float4 color = kernel[0].z * sample2D(target_sampler, texcoord + kernel[0].xy * pixel_size.xy) +
		kernel[1].z * sample2D(target_sampler, texcoord + kernel[1].xy * pixel_size.xy) +
		kernel[2].z * sample2D(target_sampler, texcoord + kernel[2].xy * pixel_size.xy) +
		kernel[3].z * sample2D(target_sampler, texcoord + kernel[3].xy * pixel_size.xy) +
		kernel[4].z * sample2D(target_sampler, texcoord + kernel[4].xy * pixel_size.xy);

	return color * scale;
}
