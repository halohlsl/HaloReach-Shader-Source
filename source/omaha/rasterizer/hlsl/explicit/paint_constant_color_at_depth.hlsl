//#line 2 "source\rasterizer\hlsl\paint_constant_color_at_depth.hlsl"

#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "explicit\paint_constant_color_at_depth_registers.fx"
//@generate screen

screen_output default_vs(vertex_type IN)
{
	screen_output OUT;

	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.z=		depth_value;
	OUT.position.w=		1.0f;

	return OUT;
}

// pixel fragment entry points
float4 default_ps(screen_output IN) : SV_Target
{
	return scale.rgba;
}
