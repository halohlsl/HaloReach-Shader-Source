//#line 1 "source\rasterizer\hlsl\screenshot_combine.hlsl"

//@generate screen

// non-antialiased (screenshots should never take antialiased pathway)
//@entry default

#include "hlsl_constant_globals.fx"

#define CALC_BLOOM calc_bloom_screenshot
float4 calc_bloom_screenshot(in float2 texcoord);


#include "postprocess\final_composite_base.hlsl"

// Note that we're expecting the texture coordinate already be transformed to pixel space when this method is called:
float4 calc_bloom_screenshot(in float2 pixel_space_texcoord)
{
	// sample bloom super-smooth bspline!
	// bloom has -2 exp bias, but +5 exp surface. Total +3 exp bias
	return tex2D_bspline(bloom_sampler, pixel_space_texcoord) * 8;

}

