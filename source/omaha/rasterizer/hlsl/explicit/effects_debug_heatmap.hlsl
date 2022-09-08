//#line 2 "source\rasterizer\hlsl\effects_debug_wireframe.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

//@generate world

//@entry default

void default_vs(
	in vertex_type vertex,
	out float4 position : SV_Position)
{
    float4 local_to_world_transform[3];
	deform(vertex, local_to_world_transform);
	position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
}

float4 default_ps(in float4 position : TEXCOORD0) : SV_Target
{
	return float4(0.1f, 0.01f, 0.01f, 0.1f);
}
