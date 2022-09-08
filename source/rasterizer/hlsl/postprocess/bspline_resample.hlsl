//#line 2 "source\rasterizer\hlsl\bspline_resample.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
#include "postprocess\bspline_resample_registers.fx"
//@generate screen

LOCAL_SAMPLER_2D(surface_sampler, 0);

// pixel fragment entry points
float4 default_ps(screen_output IN) : SV_Target
{
	return tex2D_bspline(surface_sampler, transform_texcoord(IN.texcoord, surface_sampler_xform));
}
