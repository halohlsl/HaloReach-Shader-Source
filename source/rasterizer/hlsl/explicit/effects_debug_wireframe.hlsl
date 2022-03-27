//#line 2 "source\rasterizer\hlsl\effects_debug_wireframe.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

//@generate world

//@entry default

extern float4 debugColor: register(c58);

void default_vs(
	in vertex_type vertex,
	out float4 position : POSITION)
{
    float4 local_to_world_transform[3];
	deform(vertex, local_to_world_transform);
	position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
}

float4 default_ps(in float2 texcoord : TEXCOORD0) : COLOR
{
	return debugColor;
}
