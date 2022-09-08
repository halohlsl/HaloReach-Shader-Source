//#line 1 "source\rasterizer\hlsl\player_emblem_world.hlsl"
/*
player_emblem_world.hlsl
Copyright (c) Microsoft Corporation, 2007. All rights reserved.
Friday February 23, 2007, 12:05pm Stefan S.

*/

/* ---------- headers */

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"

#undef PIXEL_CONSTANT
#undef VERTEX_CONSTANT
#include "explicit\player_emblem.fx"
#include "templated\deform.fx"
// the following are needed for using convert_to_render_target()
#define LDR_ONLY
#include "shared\render_target.fx" //convert_to_render_target

// compile this shader for various needed vertex types
//@generate world

/* ---------- public code */

// vertex fragment entry points
// stolen from post_process.fx - declaration conflicts force this
struct s_screen_output
{
	float4 position : SV_Position;
	float2 texcoord : TEXCOORD0;
	float4 color : COLOR;
};

s_screen_output default_vs(vertex_type IN)
{
	s_screen_output out_vertex;
	
	out_vertex.texcoord= IN.texcoord;
	out_vertex.position.xyz= IN.position;
	out_vertex.position.w= 1.0f;
	out_vertex.color= float4(1.f, 1.f, 1.f, 1.f); //IN.color;
	
	return out_vertex;
}

// pixel fragment entry points

accum_pixel default_ps(s_world_vertex IN) : SV_Target
{
	float4 emblem_pixel= calc_emblem(IN.texcoord, true);
	
	return convert_to_render_target(emblem_pixel, false, false);
}
