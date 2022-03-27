//#line 2 "source\rasterizer\hlsl\gamma_correct.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
//@generate screen

sampler2D surface_sampler : register(s0);

PIXEL_CONSTANT(float4, gamma_power, POSTPROCESS_DEFAULT_PIXEL_CONSTANT);		// gamma power, stored in red channel

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	float4 pixel=		tex2D(surface_sampler, IN.texcoord);
	pixel.rgb= pow(pixel.bgr, gamma_power.r);
	pixel.a= 1.0f; 
	return pixel;
}
