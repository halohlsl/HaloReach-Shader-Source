////#line 2 "source\rasterizer\hlsl\patchy_fog.hlsl"

//@generate screen

// apply
//@entry default

// prepass
//@entry albedo


#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\render_target.fx"


#undef PIXEL_CONSTANT
#undef VERTEX_CONSTANT
#include "hlsl_registers.fx"
#define	SHADER_CONSTANT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, register_bank, stage, command_buffer_option)		hlsl_type hlsl_name stage##_REGISTER(register_bank##register_start);
	#include "hlsl_constant_declaration_defaults.fx"
	#include "explicit\patchy_fog_registers.fx"
	#include "hlsl_constant_declaration_defaults_end.fx"
#undef SHADER_CONSTANT
#undef VERTEX_REGISTER
#undef PIXEL_REGISTER

//#include "explicit\patchy_effect.fx"

struct s_vertex_out
{
	float4 position : POSITION;
	float4 texcoord : TEXCOORD0;
	float4 world_space : TEXCOORD1;
};
struct s_vertex_out_default
{
	float4 position : POSITION;
	float4 texcoord : TEXCOORD0;
};

s_vertex_out_default default_vs(vertex_type IN)
{
	s_vertex_out_default OUT;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	float2(k_vs_z_epsilon.x, 1.0f);
	OUT.texcoord.xy=	IN.texcoord;
	OUT.texcoord.zw=	IN.texcoord * float2(2, -2) + float2(-1, 1);
	return OUT;
}

s_vertex_out albedo_vs(vertex_type IN)
{
	s_vertex_out OUT;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	float2(k_vs_z_epsilon.x, 1.0f);
	OUT.texcoord.xy=	IN.texcoord;
	OUT.texcoord.zw=	IN.texcoord * float2(2, -2) + float2(-1, 1);

	float4 world_space=	mul(OUT.position.xyzw, transpose(k_vs_proj_to_world_relative));
	OUT.world_space=	float4(world_space.xyz / world_space.w, 1.0f);

	return OUT;
}



struct s_prepass_output
{
	float4 color0 : COLOR0;
	float4 color1 : COLOR1;
};



float2 calc_warp_offset(float2 texcoord_biased)			// [-1, 1] across warp area (center of warp is 0,0)
{
	float2 delta=		texcoord_biased * k_ps_projective_to_tangent_space;
	float delta2=		dot(delta.xy, delta.xy);
	float delta4=		delta2 * delta2;
	float delta6=		delta4 * delta2;

//	better approximation, but more expensive:
//	float delta6=			delta2 * delta2 * delta2;
//	float delta_offset=		delta2 * 0.05f + delta6 * 0.37f;				// ###ctchou $TODO we could give artists control of this polynomial if they want..  maybe default it to the sphere control, but let them do whatever..

	// best, but more expensive
//	float delta_offset=		delta2 * -0.108f + delta4 * -0.167f + delta6 * 0.06f;

	// really good over low angles (<80 degrees fov), sucks over that
//	float delta_offset=		delta2 * -0.15f + delta4 * -0.06f;

	// not as good at low angles, but better over larger angles	
	float delta_offset=		delta2 * -0.185f + delta4 * -0.023f;

	// exact (and EXTREMELY expensive)
//	float delta_offset=		atan(sqrt(delta2)) - sqrt(delta2);
	
	float2 offset=			(delta.xy * delta_offset) / k_ps_projective_to_tangent_space;

	return offset;
}


s_prepass_output albedo_ps(s_vertex_out pixel_in) : COLOR0
{
	// Window coordinates with [0,0] at the center, [1,1] at the upper right, and [-1,-1] at the lower left
	float2 screen_normalized_biased= pixel_in.texcoord.zw + calc_warp_offset(pixel_in.texcoord.zw);

	float4 noise_values0, noise_values1;	
	{
		float4 noise_uvs;
		
		// the texcoord transforms are computed using a single matrix multiplication per sheet, and we go double-wide to compute two texcoords at once
		noise_uvs=			k_ps_texcoord_offsets[0].xyzw +
							k_ps_texcoord_x_scale[0].xyzw * screen_normalized_biased.x +
							k_ps_texcoord_y_scale[0].xyzw * screen_normalized_biased.y;
		noise_values0.x=	tex2D(k_ps_sampler_tex_noise, noise_uvs.xy).x;
		noise_values0.y=	tex2D(k_ps_sampler_tex_noise, noise_uvs.zw).x;

		noise_uvs=			k_ps_texcoord_offsets[1].xyzw +
							k_ps_texcoord_x_scale[1].xyzw * screen_normalized_biased.x +
							k_ps_texcoord_y_scale[1].xyzw * screen_normalized_biased.y;
		noise_values0.z=	tex2D(k_ps_sampler_tex_noise, noise_uvs.xy).x;
		noise_values0.w=	tex2D(k_ps_sampler_tex_noise, noise_uvs.zw).x;

		noise_uvs=			k_ps_texcoord_offsets[2].xyzw +
							k_ps_texcoord_x_scale[2].xyzw * screen_normalized_biased.x +
							k_ps_texcoord_y_scale[2].xyzw * screen_normalized_biased.y;
		noise_values1.x=	tex2D(k_ps_sampler_tex_noise, noise_uvs.xy).x;
		noise_values1.y=	tex2D(k_ps_sampler_tex_noise, noise_uvs.zw).x;

		noise_uvs=			k_ps_texcoord_offsets[3].xyzw +
							k_ps_texcoord_x_scale[3].xyzw * screen_normalized_biased.x +
							k_ps_texcoord_y_scale[3].xyzw * screen_normalized_biased.y;
		noise_values1.z=	tex2D(k_ps_sampler_tex_noise, noise_uvs.xy).x;
		noise_values1.w=	tex2D(k_ps_sampler_tex_noise, noise_uvs.zw).x;
	}

	noise_values0 *= pow(saturate(k_ps_height_fade_scales[0].xyzw * pixel_in.world_space.z + k_ps_height_fade_offset[0].xyzw), 2) * k_ps_sheet_fade[0];
	noise_values1 *= pow(saturate(k_ps_height_fade_scales[1].xyzw * pixel_in.world_space.z + k_ps_height_fade_offset[1].xyzw), 2) * k_ps_sheet_fade[1];
	
	s_prepass_output output;
	output.color0=	noise_values0;
	output.color1=	noise_values1;
	return output;
}


accum_pixel default_ps(s_vertex_out_default pixel_in)
{
	// Screen coordinates with [0,0] in the upper left and [1,1] in the lower right
	float2 screen_normalized_uv=		pixel_in.texcoord.xy;
	float scene_depth=					tex2D(k_ps_sampler_tex_scene_depth, screen_normalized_uv).x;
	
	// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
	float2 view_space_scene_depth=		k_ps_inverse_z_transform.xy * scene_depth + k_ps_inverse_z_transform.zw;
	
	// Homogenous divide
//	view_space_scene_depth.x /= -view_space_scene_depth.y;
	// optimized -- relies on the fact that we know view_space_scene_depth.x == -1.0 for our standard projections
	view_space_scene_depth.x=	1.0f / view_space_scene_depth.y;
	
	// evaluate patchy effect
	float inv_inscatter;
	{
		float4 fade_factor0=	saturate(view_space_scene_depth.xxxx * k_ps_depth_fade_scales[0] + k_ps_depth_fade_offset[0]);
		float4 fade_factor1=	saturate(view_space_scene_depth.xxxx * k_ps_depth_fade_scales[1] + k_ps_depth_fade_offset[1]);
	
		float4 noise_values0=	tex2D(k_ps_sampler_patchy_buffer0, screen_normalized_uv);
		float4 noise_values1=	tex2D(k_ps_sampler_patchy_buffer1, screen_normalized_uv);
		noise_values0 *= noise_values0;
		noise_values1 *= noise_values1;
				
		// The line integral of fog is simply the sum of the products of fade factors and noise values
		float optical_depth= dot(fade_factor0, noise_values0) + dot(fade_factor1, noise_values1);

		// scattering calculations	
//		inscatter=		1.0f-exp2(optical_depth * k_ps_optical_depth_scale.x);			// optical depth scale
		inv_inscatter=	exp2(optical_depth * k_ps_optical_depth_scale.x);			// optical depth scale
	}
	
//	return convert_to_render_target(float4(lerp(k_ps_tint_color.rgb, k_ps_tint_color2.rgb, inscatter) * g_exposure.r, inscatter), false, true);	
	return convert_to_render_target(float4(lerp(k_ps_tint_color2.rgb, k_ps_tint_color.rgb, inv_inscatter) * g_exposure.r, inv_inscatter), false, true);	
}