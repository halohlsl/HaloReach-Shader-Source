//#line 2 "source\rasterizer\hlsl\gamma_correct.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
//@generate screen

#define gamma_power scale

LOCAL_SAMPLER_2D(surface_sampler, 0);

// pixel fragment entry points
float4 default_ps(screen_output IN) : SV_Target
{
	float4 pixel=		sample2D(surface_sampler, IN.texcoord);
	pixel.rgb= pow(pixel.bgr, gamma_power.r);
	pixel.a= 1.0f;
	return pixel;
}
