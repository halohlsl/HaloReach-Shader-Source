//#line 2 "source\rasterizer\hlsl\particle_overdraw_apply.hlsl"

#define POSTPROCESS_COLOR

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture.fx"
#include "shared\read_cmask.fx"

#ifdef durango
#include "effects\particle_overdraw_apply_registers.fx"
#include "shared\procedural_geometry.fx"
#endif

//@generate screen
//@entry default
//@entry albedo
//@entry static_sh


LOCAL_SAMPLER_2D(source_sampler, 0);


// pixel blur width (must be a multilpe of 0.5)
#define DELTA 0.5

float4 overdraw_apply(screen_output IN, in bool use_cmask, in bool is_xboxone_x)
{
	float4 color;
#if defined(pc) && (DX_VERSION != 11)
 	color= sample2D(source_sampler, IN.texcoord);
#else // xenon
//	color= tex2D_bspline_fast_2x(source_sampler, IN.texcoord);
// 	color= tex2D(source_sampler, IN.texcoord);

#ifdef xenon
	float2 texcoord0= IN.texcoord + pixel_size.xy * 0.25f;
	float2 texcoord1= IN.texcoord - pixel_size.xy * 0.25f;
	float4 tex0, tex1;
	asm
	{
//		tfetch2D tex0, texcoord, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled, OffsetX= +DELTA, OffsetY= +DELTA
//		tfetch2D tex1, texcoord, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled, OffsetX= -DELTA, OffsetY= -DELTA
		tfetch2D tex0, texcoord0, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
		tfetch2D tex1, texcoord1, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
	};
	color.rgb= (tex0.rgb + tex1.rgb) * 0.5f;
//	color.rgb= min(tex0.rgb, tex1.rgb);

//	color.a= min(tex0.a, tex1.a) * 0.75f + (tex0.a + tex1.a) * 0.125f;		// this results in a slightly lighter edge darkening than a straight 'min' function
	color.a= (tex0.a + tex1.a) * 0.5f;
#elif durango
	bool is_valid = true;

	if (use_cmask)
	{
		float2 pixel_coord = (IN.texcoord * overdraw_size) - 0.5;
		color = bilinear_sample_compressed_texture(source_sampler.t, cmask_buffer, cmask_pitch, pixel_coord, is_xboxone_x);
	} else
	{
		color = sample2D(source_sampler, IN.texcoord);
	}
#elif DX_VERSION == 11
	color = sample2D(source_sampler, IN.texcoord);
#endif
#endif
 	return color*scale;
}

float4 default_ps(screen_output IN) : SV_Target
{
	return overdraw_apply(IN, false, false);
}

float4 albedo_ps(screen_output IN) : SV_Target
{
	return overdraw_apply(IN, true, false);
}

float4 static_sh_ps(screen_output IN) : SV_Target
{
	return overdraw_apply(IN, true, true);
}

#ifdef durango

screen_output default_vs(
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID)
{
	screen_output OUT;

	uint2 tile_coord = tile_buffer[instance_id];
	float2 quad_point = generate_quad_point_2d(vertex_id);

	OUT.position = float4(((tile_coord * tile_scale_offset.xy) + tile_scale_offset.zw) + (quad_point * quad_scale.xy), 0, 1);
	OUT.texcoord = (tile_coord + quad_point) * quad_scale.zw;

	return OUT;
}

screen_output albedo_vs(
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID)
{
	return default_vs(instance_id, vertex_id);
}

screen_output static_sh_vs(
	in uint instance_id : SV_InstanceID,
	in uint vertex_id : SV_VertexID)
{
	return default_vs(instance_id, vertex_id);
}

#endif
