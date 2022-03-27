//#line 2 "source\rasterizer\hlsl\kernel_5_sqrt.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D target_sampler : register(s0);
PIXEL_CONSTANT(float4, kernel[5], POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);		// 5 tap kernel, (x offset, y offset, weight),  offsets should be premultiplied by pixel_size

float4 default_ps(screen_output IN) : COLOR
{
	float2 sample= IN.texcoord;
	
	float4 color=	kernel[0].z * tex2D(target_sampler, sample + kernel[0].xy * pixel_size.xy) +
					kernel[1].z * tex2D(target_sampler, sample + kernel[1].xy * pixel_size.xy) +
					kernel[2].z * tex2D(target_sampler, sample + kernel[2].xy * pixel_size.xy) +
					kernel[3].z * tex2D(target_sampler, sample + kernel[3].xy * pixel_size.xy) +
					kernel[4].z * tex2D(target_sampler, sample + kernel[4].xy * pixel_size.xy);

	return float4(sqrt(color.rgb), color.a) * scale;
}
