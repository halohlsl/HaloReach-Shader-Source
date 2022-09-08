//#line 2 "source\rasterizer\hlsl\downsize_2x_to_bloom.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);
LOCAL_SAMPLER_2D(dark_source_sampler, 1);


float4 default_ps(screen_output IN) : SV_Target
{
#ifdef pc
	float3 color= 0.00000001f;			// hack to keep divide by zero from happening on the nVidia cards
#else
	float3 color= 0.0f;
#endif

	color += tex2D_offset(source_sampler, IN.texcoord, -1, -1);
	color += tex2D_offset(source_sampler, IN.texcoord, +1, -1);
	color += tex2D_offset(source_sampler, IN.texcoord, -1, +1);
	color += tex2D_offset(source_sampler, IN.texcoord, +1, +1);

	color= color * DARK_COLOR_MULTIPLIER / 4.0f;


	float4 intensity_vector=	{0.299, 0.587, 0.114, 0.0};

	// calculate 'intensity'		(max or dot product?)
	float intensity= dot(color.rgb, intensity_vector.rgb);					// max(max(color.r, color.g), color.b);

	// calculate bloom curve intensity
	float bloom_intensity=	(scale.x * intensity + scale.y) * intensity;		// blend of quadratic (highlights) and linear (inherent)

	// calculate bloom color
	float3 bloom_color= color * (bloom_intensity / intensity);

	return float4(bloom_color.rgb, intensity);
}
