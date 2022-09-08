#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "effects\blend_particle_overdraw_registers.fx"
#include "shared\procedural_geometry.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture.fx"

//@generate screen

#ifdef durango

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(
	in float4 position : SV_Position,
	in float2 texcoord : TEXCOORD0) : SV_Target
{
	float2 texcoord0= texcoord + pixel_size.xy * 0.25f;
	float2 texcoord1= texcoord - pixel_size.xy * 0.25f;
	float4 tex0 = sample2D(source_sampler, texcoord0);
	float4 tex1 = sample2D(source_sampler, texcoord1);

	float4 color;
	color.rgb= (tex0.rgb + tex1.rgb) * 0.5f;
	color.a= (tex0.a + tex1.a) * 0.5f;

	return color * scale;
}

void default_vs(
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0)
{
	uint2 tile_coord = tile_buffer[instance_id];
	float2 quad_point = generate_quad_point_2d(vertex_id);

	position = float4(((tile_coord * tile_scale_offset.xy) + tile_scale_offset.zw) + (quad_point * quad_scale.xy), 0, 1);
	texcoord = (tile_coord + quad_point) * quad_scale.zw;
}

#endif
