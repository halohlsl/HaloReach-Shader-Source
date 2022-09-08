//#line 2 "source\rasterizer\hlsl\downsample_4x4_block_bloom.hlsl"


#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\downsample_registers.fx"
//@generate screen


LOCAL_SAMPLER_2D(source_sampler, 0);





float4 default_ps(screen_output IN) : SV_Target
{
#ifdef pc
	float3 color= 0.00000001f;						// hack to keep divide by zero from happening on the nVidia cards
#else
	float3 color= 0.0f;
#endif

	float4 sample0= tex2D_offset(source_sampler, IN.texcoord, -1, -1);
	float4 sample1= tex2D_offset(source_sampler, IN.texcoord, +1, -1);
	float4 sample2= tex2D_offset(source_sampler, IN.texcoord, -1, +1);
	float4 sample3= tex2D_offset(source_sampler, IN.texcoord, +1, +1);

//	sample0.rgb= exp2(sample0.rgb * 8.0f - 8.0f);
//	sample1.rgb= exp2(sample1.rgb * 8.0f - 8.0f);
//	sample2.rgb= exp2(sample2.rgb * 8.0f - 8.0f);
//	sample3.rgb= exp2(sample3.rgb * 8.0f - 8.0f);

	color += sample0.rgb;
	color += sample1.rgb;
	color += sample2.rgb;
	color += sample3.rgb;
	color= color * DARK_COLOR_MULTIPLIER / 4.0f;

	// calculate 'intensity'		(max or dot product?)
	float intensity= dot(color.rgb, intensity_vector.rgb);					// max(max(color.r, color.g), color.b);

	// calculate bloom curve intensity
	float bloom_intensity= max(intensity*scale.y, intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max

	// calculate bloom color
	float3 bloom_color= color * (bloom_intensity / intensity);

	return float4(bloom_color.rgb, intensity);
}
