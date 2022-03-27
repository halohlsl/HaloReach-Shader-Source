//#line 2 "source\rasterizer\hlsl\copy_surface.hlsl"

#define POSTPROCESS_COLOR

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
 	float4 color= tex2D(source_sampler, IN.texcoord);
 	color *= IN.color * scale;
 	color.rgb=	sqrt(color.rgb);
	return color;
}
