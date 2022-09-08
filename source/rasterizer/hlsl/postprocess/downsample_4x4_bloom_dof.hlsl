//#line 2 "source\rasterizer\hlsl\downsample_4x4_bloom_DOF.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);
LOCAL_SAMPLER_2D(dark_source_sampler, 1);


accum_pixel default_ps(screen_output IN)
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

	color= color / 4.0f;

	float maximum= max(max(color.r, color.g), color.b);
	float overwhite= max(maximum*scale.y, maximum-scale.x);		// ###ctchou $PERF could compute both paramters with a single mad followed by max

	accum_pixel result;
	result.color.rgb= color * (overwhite / maximum);
	result.color.a= 1.0f;
#ifndef LDR_ONLY
	result.dark_color.rgb= color;
	result.dark_color.a= 1.0f;
#endif
	return result;
}
