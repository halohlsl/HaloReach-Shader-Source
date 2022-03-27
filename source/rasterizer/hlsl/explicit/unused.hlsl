//#line 2 "source\rasterizer\hlsl\unused.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


float4 default_ps(screen_output IN) : COLOR
{
	return float4(1.0f, 0.0f, 1.0f, 0.5f);
}
