//#line 2 "source\rasterizer\hlsl\copy.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
 	return tex2D(source_sampler, IN.texcoord * scale.xy);
}
