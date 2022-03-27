//#line 2 "source\rasterizer\hlsl\bspline_resample.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
//@generate screen

sampler2D surface_sampler : register(s0);
PIXEL_CONSTANT(float4, surface_sampler_xform, c3);

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	return tex2D_bspline(surface_sampler, transform_texcoord(IN.texcoord, surface_sampler_xform));
}
