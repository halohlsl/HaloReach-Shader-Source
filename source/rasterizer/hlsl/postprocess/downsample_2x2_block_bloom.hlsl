//#line 2 "source\rasterizer\hlsl\downsample_restore.hlsl"


#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


sampler2D source_sampler : register(s0);



PIXEL_CONSTANT(float4, intensity_vector, POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);		// intensity vector (default should be NTSC weightings: 0.299, 0.587, 0.114)


void default_ps(
	in screen_output IN,
	out float4	color0	:	COLOR0)
{
	float4 sample0= tex2D(source_sampler, IN.texcoord);
		
	float3	color=	sample0.rgb * DARK_COLOR_MULTIPLIER;

	// calculate 'intensity'		(max or dot product?)
	float intensity= dot(color.rgb, intensity_vector.rgb);					// max(max(color.r, color.g), color.b);
	
	// calculate bloom color
//	float bloom_intensity=	(scale.x * intensity + scale.y) * intensity;		// blend of quadratic (highlights) and linear (inherent)
//	float3 bloom_color= color * (bloom_intensity / intensity);

	float	bloom_scale=	(scale.x * intensity + scale.y);
	float3	bloom_color=	color * bloom_scale;
	
//	color0=		float4(bloom_color.rgb, intensity);
	color0=		float4(bloom_color.rgb, intensity);
}



/* 

// optimized (doesn't matter because this thing is tfetch bound)


float4 scaled_intensity_vector;		// intensity_vector * DARK_COLOR_MULTIPLIER
float4 scaled_scale;				// scale * DARK_COLOR_MULTIPLIER

void default_ps(
	in screen_output IN,
	out float4	color0	:	COLOR0)
{
	float4 sample0= tex2D(source_sampler, IN.texcoord);

	// calculate 'intensity'
	float intensity= dot(sample0.rgb, scaled_intensity_vector.rgb);
	
	// calculate bloom scale * DARK_COLOR_MULTIPLIER
	intensity=				(scaled_scale.x * intensity + scaled_scale.y);	

	// scale color
	float3	bloom_color=	sample0.rgb * intensity;
	
	color0=		float4(bloom_color.rgb, intensity);
}

*/