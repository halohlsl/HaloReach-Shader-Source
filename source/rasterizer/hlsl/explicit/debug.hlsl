//#line 1 "source\rasterizer\hlsl\debug.hlsl"

// define before render_target.fx
#ifndef LDR_ALPHA_ADJUST
#ifdef pc
#define LDR_ALPHA_ADJUST 1.0f
#endif
#endif

#define LDR_ONLY

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\render_target.fx"

//@generate debug

struct debug_output
{
	float4 HPosition	:POSITION;
    float4 Color		:COLOR0;
};

debug_output default_vs(vertex_type IN)
{
    debug_output OUT;

    OUT.HPosition= mul(float4(IN.position, 1.0f), View_Projection);
	OUT.Color= IN.color;
	
    return OUT;
}

// pixel fragment entry points

accum_pixel default_ps(debug_output IN)
{
    return convert_to_render_target(IN.Color, false, false);
}
