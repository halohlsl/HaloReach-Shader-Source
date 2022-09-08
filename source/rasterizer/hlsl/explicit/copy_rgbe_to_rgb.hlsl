//#line 2 "source\rasterizer\hlsl\copy_RGBE_to_RGB.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
{
 	float4 color= sample2D(source_sampler, IN.texcoord);
 	color.rgb=	sqrt(color.rgb);		// convert to gamma 2 space
	return color*scale;
}
