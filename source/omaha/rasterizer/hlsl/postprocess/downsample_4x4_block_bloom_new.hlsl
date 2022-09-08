//#line 2 "source\rasterizer\hlsl\downsample_4x4_block_bloom.hlsl"

#define PIXEL_SIZE

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\downsample_registers.fx"
//@generate screen


LOCAL_SAMPLER_2D(dark_source_sampler, 0);


float4 tex2D_offset_exact_bilinear(texture_sampler_2d s, const float2 texc, const float offsetx, const float offsety)
{
	float2 texcoord= texc + float2(offsetx, offsety) * pixel_size.xy;
	float4 value= 0.1f;
#ifdef xenon
#ifndef VERTEX_SHADER
	asm {
		tfetch2D value, texcoord, s, MinFilter=linear, MagFilter=linear
	};
#endif
#else
	value= sample2D(s, texcoord);
#endif
	return value;
}


float4 default_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	float3 color= 0.00000001f;						// hack to keep divide by zero from happening on the nVidia cards
#else
	float3 color= 0.0f;
#endif

	float4 sample;

#define DELTA 0.7f
#define TEXSAMPLE tex2D_offset_exact_bilinear
/*
	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, -DELTA, -DELTA);
		color += sample.rgb * sample.rgb;
	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, +DELTA, -DELTA);
		color += sample.rgb * sample.rgb;
	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, -DELTA, +DELTA);
		color += sample.rgb * sample.rgb;
	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, +DELTA, +DELTA);
		color += sample.rgb * sample.rgb;
	color= color * DARK_COLOR_MULTIPLIER / 4.0f;

	// calculate 'intensity'		(max or dot product?)
	float intensity= dot(color.rgb, intensity_vector.rgb);					// max(max(color.r, color.g), color.b);

	// calculate bloom curve intensity
	float bloom_intensity= max(intensity*scale.y, intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max

	// calculate bloom color
	float3 bloom_color= color * (bloom_intensity / intensity);
/*/

	float sample_intensity, sample_curved;
	float intensity= 0;

	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, -DELTA, -DELTA);
		sample.rgb= sample.rgb * sample.rgb;	 // min(sample.rgb, sample.rgb * sample.rgb * 16);
		sample.rgb *= DARK_COLOR_MULTIPLIER;		// * sample.rgb
		sample_intensity= dot(sample.rgb, intensity_vector.rgb);
		intensity += sample_intensity * 0.25f;
		sample_curved= max(sample_intensity*scale.y, sample_intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max
		color += sample.rgb * sample_curved / sample_intensity;

	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, +DELTA, -DELTA);
		sample.rgb= sample.rgb * sample.rgb;	 // min(sample.rgb, sample.rgb * sample.rgb * 16);
		sample.rgb *= DARK_COLOR_MULTIPLIER;		// * sample.rgb
		sample_intensity= dot(sample.rgb, intensity_vector.rgb);
		intensity += sample_intensity * 0.25f;
		sample_curved= max(sample_intensity*scale.y, sample_intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max
		color += sample.rgb * sample_curved / sample_intensity;

	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, -DELTA, +DELTA);
		sample.rgb= sample.rgb * sample.rgb;	 // min(sample.rgb, sample.rgb * sample.rgb * 16);
		sample.rgb *= DARK_COLOR_MULTIPLIER;		// * sample.rgb
		sample_intensity= dot(sample.rgb, intensity_vector.rgb);
		intensity += sample_intensity * 0.25f;
		sample_curved= max(sample_intensity*scale.y, sample_intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max
		color += sample.rgb * sample_curved / sample_intensity;

	sample= TEXSAMPLE(dark_source_sampler, IN.texcoord, +DELTA, +DELTA);
		sample.rgb= sample.rgb * sample.rgb;	 // min(sample.rgb, sample.rgb * sample.rgb * 16);
		sample.rgb *= DARK_COLOR_MULTIPLIER;		// * sample.rgb
		sample_intensity= dot(sample.rgb, intensity_vector.rgb);
		intensity += sample_intensity * 0.25f;
		sample_curved= max(sample_intensity*scale.y, sample_intensity-scale.x);		// ###ctchou $PERF could compute both parameters with a single mad followed by max
		color += sample.rgb * sample_curved / sample_intensity;
	color= color / 4.0f;

	float3 bloom_color= color;
//*/
	return float4(bloom_color.rgb, intensity);
}
