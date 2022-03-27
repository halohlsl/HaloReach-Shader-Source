//#line 2 "source\rasterizer\hlsl\paint_constant_color.hlsl"

#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

screen_output default_vs(vertex_type IN)
{
	screen_output OUT;
	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	0.0f;
	return OUT;
}

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	return scale.rgba;
}
