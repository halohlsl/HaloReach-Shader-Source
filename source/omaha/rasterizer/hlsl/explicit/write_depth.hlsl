//#line 2 "source\rasterizer\hlsl\write_depth.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

//@generate world

//@entry default
//@entry active_camo

// rename entry point of water passes 
#define memexport_blank_vs			active_camo_vs	
#define memexport_blank_ps			active_camo_ps	


void default_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	out float4 position_copy : TEXCOORD0)
{
    float4 local_to_world_transform[3];
	if (always_true)
	{
		deform(vertex, local_to_world_transform);
	}
	
	if (always_true)
	{
		position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
		position_copy= position;
	}
	else
	{
		position= float4(0,0,0,0);
		position_copy= position;
	}
}

#if DX_VERSION == 9
float4 default_ps(SCREEN_POSITION_INPUT(screen_position), in float4 position : TEXCOORD0) : SV_Target
{
	return float4(position.z, position.z, position.z, 1.0f);
}
#elif DX_VERSION == 11
void default_ps()
{
}
#endif

void memexport_blank_vs(
	out float4 position : SV_Position)
{
	position= 0.0f;
}

float4 memexport_blank_ps(void) :SV_Target0
{
	return float4(0,1,2,3);
}
