//#line 2 "source\rasterizer\hlsl\constant_color.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

#include "shared\render_target.fx"

//@generate world

struct screen_output
{
    float4 position	:SV_Position;
};

screen_output default_vs(vertex_type IN)
{
//	deform(IN);

	screen_output OUT;

    OUT.position= mul(float4(IN.position.xyz, 1.0f), View_Projection);
//    OUT.position.w= 1.0f;

	return OUT;
}

accum_pixel default_ps(screen_output IN)
{
	return convert_to_render_target(float4(1.0f, 1.0f, 0.0f, 0.3f), false, false);
}
