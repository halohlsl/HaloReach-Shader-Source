//#line 2 "source\rasterizer\hlsl\gamma_correct.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS
#define POSTPROCESS_COLOR

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
	
	// remove xenon gamma curve
	float3 slope0= pixel.rgb * (1023.000f / 255.0f) + (  0.0000f / 255.0f);
	float3 slope1= pixel.rgb * ( 511.500f / 255.0f) + ( 31.7500f / 255.0f);
	float3 slope2= pixel.rgb * ( 255.750f / 255.0f) + ( 63.6250f / 255.0f);
	float3 slope3= pixel.rgb * ( 127.875f / 255.0f) + (127.5625f / 255.0f);
	pixel.rgb= min(slope0, min(slope1, min(slope2, slope3)));
	
	// apply custom gamma
	pixel.rgb= pow(pixel.rgb, 1.95f);
	return pixel*scale*IN.color;
}
