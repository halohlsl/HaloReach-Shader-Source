//#line 1 "source\rasterizer\hlsl\screenshot_combine.hlsl"

//@generate screen

// non-antialiased (screenshots should never take antialiased pathway)
//@entry default


#define CALC_BLOOM calc_bloom_screenshot
float4 calc_bloom_screenshot(in float2 texcoord);


#include "postprocess\final_composite_base.hlsl"

// Note that we're expecting the texture coordinate already be transformed to pixel space when this method is called:
float4 calc_bloom_screenshot(in float2 pixel_space_texcoord)
{
	// sample bloom super-smooth bspline!
	return tex2D_bspline(bloom_sampler, pixel_space_texcoord);

}

