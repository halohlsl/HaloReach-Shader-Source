////#line 2 "source\rasterizer\hlsl\shield_impact.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"

#include "templated\deform.fx"

#include "shared\render_target.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
	#define VERTEX_SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
	#define PIXEL_SAMPLER_CONSTANT(name, register_index)
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define VERTEX_SAMPLER_CONSTANT(name, register_index)
	#define PIXEL_SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);

#include "explicit\shield_impact_registers.fx"

// Magic line to compile this for various needed vertex types
//@generate rigid
//@generate world
//@generate skinned
//@generate rigid_compressed
//@generate skinned_compressed



float2 compute_depth_fade2(float2 screen_coords, float depth, float2 inverse_range)
{
#ifdef pc
	return 1;
#else
	float4 depth_value;
	asm 
	{
		tfetch2D depth_value, screen_coords, depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};

	float scene_depth= 1.0f / (depth_constants.z - depth_value.x * depth_constants.y);	// convert to real depth
	float delta_depth= scene_depth - depth;
	
	return saturate(delta_depth * inverse_range);
#endif
}


#define EXTRUSION_DISTANCE		(vertex_params.x)
#define OSCILLATION_AMPLITUDE	(vertex_params.z)
#define OSCILLATION_SCALE		(vertex_params.w)
#define OSCILLATION_OFFSET0		(vertex_params2.xy)
#define OSCILLATION_OFFSET1		(vertex_params2.zw)

void default_vs(
	in vertex_type vertex_in,
	out float4 position				: POSITION,
	out float4 world_space_pos		: TEXCOORD0,
	out float4 texcoord				: TEXCOORD1)
{
	float4 local_to_world_transform[3];
	deform(vertex_in, local_to_world_transform);

	float3	impact_delta=				vertex_in.position -	impact0_params.xyz;
	float	impact_distance=			length(impact_delta) /	impact0_params.w;
	
	float3	world_position=				vertex_in.position.xyz + vertex_in.normal * EXTRUSION_DISTANCE;

#ifdef xenon
	float noise_value1=			tex2Dlod(shield_impact_noise_texture1, float4(world_position.xy * OSCILLATION_SCALE + OSCILLATION_OFFSET0, 0.0f, 0.0f));
	float noise_value2=			tex2Dlod(shield_impact_noise_texture2, float4(world_position.yz * OSCILLATION_SCALE + OSCILLATION_OFFSET1, 0.0f, 0.0f));

	float noise=				(noise_value1 + noise_value2 - 1.0f) * OSCILLATION_AMPLITUDE;
		
	world_position		+=		vertex_in.normal * noise;
#endif
	
	float3 camera_to_vertex=	world_position - Camera_Position.xyz;
		
	float cosine_view=		-dot(normalize(camera_to_vertex), vertex_in.normal);
	world_space_pos=		float4(world_position, cosine_view);	

	float depth=			-dot(camera_to_vertex, Camera_Backward.xyz);

	position=				mul(float4(world_position, 1.0f), View_Projection);	
	texcoord.xy=			vertex_in.texcoord.xy;
	texcoord.z=				depth;
	texcoord.w=				impact_distance;
}


#define OUTER_SCALE			(edge_scales.x)
#define INNER_SCALE			(edge_scales.y)
#define OUTER_SCALE2		(edge_scales.z)
#define INNER_SCALE2		(edge_scales.w)

#define OUTER_OFFSET		(edge_offsets.x)
#define INNER_OFFSET		(edge_offsets.y)
#define OUTER_OFFSET2		(edge_offsets.z)
#define INNER_OFFSET2		(edge_offsets.w)

#define PLASMA_TILE_SCALE1	(plasma_scales.x)
#define PLASMA_TILE_SCALE2	(plasma_scales.y)

#define PLASMA_TILE_OFFSET1	(plasma_offsets.xy)
#define PLASMA_TILE_OFFSET2	(plasma_offsets.zw)

#define PLASMA_POWER_SCALE	(plasma_scales.z)
#define PLASMA_POWER_OFFSET	(plasma_scales.w)

#define EDGE_GLOW_COLOR		(edge_glow.rgba)
#define PLASMA_COLOR		(plasma_color.rgba)
#define PLASMA_EDGE_COLOR	(plasma_edge_color.rgba)

#define INVERSE_DEPTH_FADE_RANGE	(depth_fade_params.xy)


[maxtempreg(3)] 
accum_pixel default_ps(
	in float2 vpos					: VPOS,
	in float4 position				: POSITION,
	in float4 world_space_pos		: TEXCOORD0,
	in float4 texcoord				: TEXCOORD1)
{
#ifdef xenon
	float edge_fade=			world_space_pos.w;
	float depth=				texcoord.z;
	
	float2 depth_fades=			compute_depth_fade2(vpos, depth, INVERSE_DEPTH_FADE_RANGE);

	float	edge_linear=		saturate(min(edge_fade * OUTER_SCALE + OUTER_OFFSET, edge_fade * INNER_SCALE + INNER_OFFSET));
	float	edge_plasma_linear=	saturate(min(edge_fade * OUTER_SCALE2 + OUTER_OFFSET2, edge_fade * INNER_SCALE2 + INNER_OFFSET2));
	float	edge_quartic=		pow(edge_linear, 4);
	float	edge=				edge_quartic * depth_fades.x;
	float	edge_plasma=		edge_plasma_linear * depth_fades.y;

	float	plasma_noise1=		tex2D(shield_impact_noise_texture1, texcoord.xy * PLASMA_TILE_SCALE1 + PLASMA_TILE_OFFSET1);
	float	plasma_noise2=		tex2D(shield_impact_noise_texture2, texcoord.xy * PLASMA_TILE_SCALE2 - PLASMA_TILE_OFFSET2);		// Do not change the '-' ...   it makes it compile magically (yay for the xbox shader compiler)
	float	plasma_base=		saturate(1.0f - abs(plasma_noise1 - plasma_noise2));
	float	plasma_power=		edge_plasma * PLASMA_POWER_SCALE + PLASMA_POWER_OFFSET;
	float	plasma=				pow(plasma_base, plasma_power);
	
	float4	hit_color=			impact0_color * saturate(1.0f - texcoord.w);

	float4	final_color=		edge * EDGE_GLOW_COLOR + (PLASMA_EDGE_COLOR * edge_plasma + PLASMA_COLOR + hit_color) * plasma;
	
	final_color.rgb	*=			g_exposure.r;

#else // pc
	float4	final_color=		0.0f;
#endif // xenon

	return	convert_to_render_target(final_color, false, false);	
}