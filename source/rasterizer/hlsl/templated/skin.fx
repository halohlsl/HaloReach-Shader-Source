#include "hlsl_constant_mapping.fx"
#define LDR_ALPHA_ADJUST g_exposure.w
#define HDR_ALPHA_ADJUST g_exposure.b
#define DARK_COLOR_MULTIPLIER g_exposure.g
#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"
#include "shared\render_target.fx"
#include "shared\blend.fx"
#include "shared\atmosphere.fx"
#include "templated\alpha_test.fx"
#include "shadows\shadow_generate.fx"

void albedo_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0)
{
	float4 local_to_world_transform[3];
	float3 binormal;
	
	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	// normal, tangent and binormal are all in world space
	texcoord= vertex.texcoord;
}

float4 albedo_ps(
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4) : COLOR0
{
	float approximate_specular_type= 0.66f;
	float4 albedo= float4(1.0f, 1.0f, 1.0f, approximate_specular_type);
	return albedo;
}

void static_per_pixel_vs(
	in vertex_type vertex,
	in s_lightmap_per_pixel lightmap,
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD3,
	out float3 binormal : TEXCOORD4,
	out float3 tangent : TEXCOORD5,
	out float2 lightmap_texcoord : TEXCOORD6,
	out float3 extinction : COLOR0,
	out float3 inscatter : COLOR1)
{
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	lightmap_texcoord= lightmap.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	compute_scattering(Camera_Position, vertex.position, extinction, inscatter);
}

accum_pixel static_per_pixel_ps(
	in float2 fragment_position : VPOS,
	in float2 texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD3,
	in float3 binormal : TEXCOORD4,
	in float3 tangent : TEXCOORD5,
	in float2 lightmap_texcoord : TEXCOORD6,
	in float3 extinction : COLOR0,
	in float3 inscatter : COLOR1
	) : COLOR
{
	float4 out_color= float4(1.0f, 1.0f, 1.0f, 1.0f);		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}

void dynamic_light_vs(
	in vertex_type vertex,
	out float4 position : POSITION,
	out float2 texcoord : TEXCOORD0,
	out float3 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float4 fragment_position_shadow : TEXCOORD5)
{
	//output to pixel shader
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	//binormal= vertex.binormal;

	fragment_position_shadow= mul(float4(vertex.position, 1.0f), Shadow_Projection);
	
}

accum_pixel dynamic_light_ps(
	in float2 fragment_position : VPOS,
	in float2 original_texcoord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float4 fragment_position_shadow : TEXCOORD5)
{
	float4 out_color= float4(1.0f, 1.0f, 1.0f, 1.0f);		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}

void static_prt_ambient_vs(
	in vertex_type vertex,
	out float4 position : POSITION)
{
	//output to pixel shader
	float4 local_to_world_transform[3];
	float3 binormal;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
}

void static_prt_linear_vs(
	in vertex_type vertex,
	out float4 position : POSITION)
{
	//output to pixel shader
	float4 local_to_world_transform[3];
	float3 binormal;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
}

void static_prt_quadratic_vs(
	in vertex_type vertex,
	out float4 position : POSITION)
{
	//output to pixel shader
	float4 local_to_world_transform[3];
	float3 binormal;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
}

accum_pixel static_prt_ps(
	in float2 fragment_position : VPOS)
{
	float4 out_color= float4(1.0f, 1.0f, 1.0f, 1.0f);
	return convert_to_render_target(out_color, true, true);
}


void static_sh_vs(
	in vertex_type vertex,
	out float4 position : POSITION)
{
	//output to pixel shader
	float4 local_to_world_transform[3];
	float3 binormal;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);
}

accum_pixel static_sh_ps(
	in float2 fragment_position : VPOS)
{
	float4 out_color= float4(1.0f, 1.0f, 1.0f, 1.0f);
	return convert_to_render_target(out_color, true, true);
}
