#include "shared\clip_plane.fx"


void active_camo_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 perturb : TEXCOORD0)
{
	perturb.x= dot(vertex.normal, -Camera_Right);		// technically we should do this dot product after transformation, to put the distortion in world space, but it's not that obvious and this lets us skip the entire normal transformation
   	perturb.y= dot(vertex.normal, Camera_Up);

  	float4 local_to_world_transform[3];
	float3 binormal;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, binormal);

	// Perspective correction so we don't distort too much in the distance
	// (and clamp the amount we distort in the foreground too)
	float distance_warp_fade=	1.0f / max(0.5f, length(vertex.position - Camera_Position));

	perturb.xy	*=		k_vs_active_camo_factor.yz * distance_warp_fade;

	CALC_CLIP(position);
}


float4 active_camo_ps(
	SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
	in float2 perturb : TEXCOORD0) : SV_Target
{
	float4 color;
#ifdef pc
	float2 dim;
	scene_ldr_texture.t.GetDimensions(dim.x, dim.y);

	float2 uv = (screen_position.xy / dim) + ((perturb.xy* float2(1152, 720)) / dim);
	color=			sample2D(scene_ldr_texture, uv.xy);
#else // xenon
	screen_position.xy= screen_position.xy + perturb.xy * texture_size.xy;

	// NOTE: sampler actually returns color / 16
	asm
	{
		tfetch2D	color.rgb, screen_position.xy, scene_ldr_texture, UnnormalizedTextureCoords=true, MagFilter=linear, MinFilter=linear, MipFilter=point, AnisoFilter=disabled
	};

	// cheap approximation to 7e3 format
//	color.rgb=	exp2(color.rgb * (8 * 8) - 8) * (1.0f + 8.0f * (exp2(-9))) - (exp2(-9));
	color.rgb=	(color.rgb < (1.0f/(16.0f*16.0f))) ? color.rgb : (exp2(color.rgb * (16 * 8) - 8));

#endif // xenon

	return float4(color.rgb, k_ps_active_camo_factor.x);
}
