//#line 2 "source\rasterizer\hlsl\downsample_depth.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(ps_surface_sampler,	0);

float default_ps(screen_output input) : SV_Depth
{
	float4 d = ps_surface_sampler.t.Gather(ps_surface_sampler.s, input.texcoord);
	return max(max(d.x, d.y), max(d.z, d.w));
}
