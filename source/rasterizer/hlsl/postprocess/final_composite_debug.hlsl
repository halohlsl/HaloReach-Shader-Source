//#line 1 "source\rasterizer\hlsl\final_composite.hlsl"

//@generate screen

// non-antialiased
//@entry default

// antialiased centered
//@entry albedo

// antialiased non-centered
//@entry static_sh

// non-antialiased save frame
//@entry shadow_apply


float4 default_combine_hdr_ldr(in float2 texcoord);							// supports multiple sources and formats, but much slower than the optimized version
#define COMBINE default_combine_hdr_ldr


#include "postprocess\final_composite_base.hlsl"


float4 default_combine_hdr_ldr(in float2 texcoord)							// supports multiple sources and formats, but much slower than the optimized version
{
	float4 accum=		tex2D(surface_sampler, texcoord);
	float4 accum_dark=	tex2D(dark_surface_sampler, texcoord);
	float4 combined=	max(accum, accum_dark * DARK_COLOR_MULTIPLIER);		// convert_from_render_targets <-- for some reason this isn't optimized very well
	return combined;
}

