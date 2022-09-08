//#line 2 "source\rasterizer\hlsl\downsample_4x4_block_bloom_LDR.hlsl"


#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\downsample_registers.fx"
//@generate screen


LOCAL_SAMPLER_2D(source_sampler, 1);
LOCAL_SAMPLER_2D(bloom_sampler, 0);


float4 default_ps(screen_output IN, SCREEN_POSITION_INPUT(screen_pos)) : SV_Target
{
#ifdef pc
	float3 color= 0.00000001f;						// hack to keep divide by zero from happening on the nVidia cards
#else
	float3 color= 0.0f;
#endif

	float4 sample= tex2D_offset(source_sampler, IN.texcoord, -1, -1);
		color += sample.rgb;
	sample= tex2D_offset(source_sampler, IN.texcoord, +1, -1);
		color += sample.rgb;
	sample= tex2D_offset(source_sampler, IN.texcoord, -1, +1);
		color += sample.rgb;
	sample= tex2D_offset(source_sampler, IN.texcoord, +1, +1);
		color += sample.rgb;
	color= color * DARK_COLOR_MULTIPLIER / 4.0f;

	// calculate 'intensity'		(max or dot product?)
	float intensity= dot(color.rgb, intensity_vector.rgb);					// max(max(color.r, color.g), color.b);

	// calculate bloom curve intensity
//	float bloom_intensity= max(intensity*scale.y, intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max
//	float over_bloom=	max(intensity - scale.x, 0.0f);
//	float bloom_intensity=	intensity * scale.y + over_bloom * over_bloom;
//	float bloom_intensity=	max(sqrt(intensity) * scale.y, intensity-scale.x);
//	float bloom_intensity=	max(intensity*intensity * scale.y, intensity-scale.x);

	float bloom_intensity=	(scale.x * intensity + scale.y) * intensity;		// blend of quadratic (highlights) and linear (inherent)

	// calculate bloom color
	float3 bloom_color= color * (bloom_intensity / intensity);

	return float4(bloom_color.rgb, intensity);

}
