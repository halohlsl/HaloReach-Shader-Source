//#line 2 "source\rasterizer\hlsl\final_composite_DOF.hlsl"

//@generate screen

// non-antialiased
//@entry default

// antialiased centered
//@entry albedo

// antialiased non-centered
//@entry static_sh

// non-antialiased save frame
//@entry shadow_apply


#ifndef pc

#define COMBINE		combine_dof
#define COMBINE_AA	combine_dof_antialiased

float4 combine_dof(in float2 texcoord);
float4 combine_dof_antialiased(in float2 texcoord, in bool centered);

#endif // !pc


#include "postprocess\final_composite_base.hlsl"


#ifndef pc

// depth of field
#define DEPTH_BIAS			depth_constants.x
#define DEPTH_SCALE			depth_constants.y
#define FOCUS_DISTANCE		depth_constants.z
#define APERTURE			depth_constants.w
#define FOCUS_HALF_WIDTH	depth_constants2.x
#define MAX_BLUR_BLEND		depth_constants2.y
#include "postprocess\DOF_filter.fx"


float4 combine_dof(in float2 texcoord)
{
	return simple_DOF_filter(texcoord, surface_sampler, false, blur_sampler, depth_sampler);
}

float4 combine_dof_antialiased(in float2 texcoord, in bool centered)
{
	// ###ctchou $TODO
	return simple_DOF_filter(texcoord, surface_sampler, false, blur_sampler, depth_sampler);
}


#endif // !pc
