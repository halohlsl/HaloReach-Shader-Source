//#line 2 "source\rasterizer\hlsl\copy_RGBE_to_RGB.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
 	float4 color= tex2D(source_sampler, IN.texcoord);
 	color.rgb=	sqrt(color.rgb);		// convert to gamma 2 space
	return color*scale;
}
