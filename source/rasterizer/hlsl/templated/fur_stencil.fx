// .shader_fur

#define NO_WETNESS_EFFECT
#include "templated\templated_globals.fx"

#define DETAIL_MULTIPLIER 4.59479f

#include "templated\deform.fx"
#include "shared\texture_xform.fx"

#include "templated\alpha_test.fx"
#include "shared\texture_xform.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"




void default_vs(						// stencil pass
	in vertex_type vertex,
	out float4 position						: POSITION,
	out float2 texcoord						: TEXCOORD0)
{
	float4 local_to_world_transform[3];
	float3 binormal;
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	texcoord=						vertex.texcoord;	
}


float4 default_ps(						// stencil pass
	in float2 texcoord						: TEXCOORD0) : COLOR0
{
	// alpha test (clips pixel internally)
	calc_alpha_test_ps(texcoord);
	
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}



void shadow_generate_vs(	
	in vertex_type vertex,
	out float4 screen_position				: POSITION,
#ifdef pc	
	out float4 screen_position_copy			: TEXCOORD0,
#endif // pc
	out float2 texcoord						: TEXCOORD1)
{
	float4 local_to_world_transform[3];
	float3 binormal;
	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, screen_position, binormal);

#ifdef pc
	screen_position_copy=	screen_position;	
#endif // pc

   	texcoord=				vertex.texcoord;
}


float4 shadow_generate_ps(
#ifdef pc
	in float4 screen_position				: TEXCOORD0,
#endif // pc
	in float2 texcoord						: TEXCOORD1) : COLOR
{
	// alpha test (clips pixel internally)
	float alpha=	calc_alpha_test_ps(texcoord);

#ifdef pc
	float buffer_depth= screen_position.z / screen_position.w;
	return float4(buffer_depth, buffer_depth, buffer_depth, alpha);
#else // xenon
	return float4(0.0f, 0.0f, 0.0f, 0.0f);
#endif // xenon
}

