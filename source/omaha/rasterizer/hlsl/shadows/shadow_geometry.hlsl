//#line 2 "source\rasterizer\hlsl\shadow_geometry.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

//@generate tiny_position

#include "shared\render_target.fx"


void default_vs(
	in vertex_type vertex,
	out float4 position : SV_Position)
{
    float4 local_to_world_transform[3];
	if (always_true)
	{
		deform(vertex, local_to_world_transform);
	}

	if (always_true)
	{
		position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
	}
	else
	{
		position= float4(0,0,0,0);
	}
}


accum_pixel default_ps()
{
	return convert_to_render_target(p_lighting_constant_0, false, false);
}
