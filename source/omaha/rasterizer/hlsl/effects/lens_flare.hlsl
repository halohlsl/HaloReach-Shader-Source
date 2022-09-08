//#line 2 "source\rasterizer\hlsl\lens_flare.hlsl"

#define POSTPROCESS_COLOR
#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "hlsl_constant_globals.fx"
#include "effects\lens_flare_registers.fx"
#include "postprocess\postprocess_registers.fx"

//@generate screen

void default_vs(
	vertex_type IN,
	out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0)
{
	float sin_theta= sin(center_rotation.z);
	float cos_theta= cos(center_rotation.z);

	position.y= dot(float2(cos_theta, -sin_theta),	IN.position.xy);
	position.x= dot(float2(sin_theta, cos_theta),	IN.position.xy);
	position.xy= position.xy * flare_scale.xy * flare_scale.z + center_rotation.xy;

	position.zw=	1.0f;
	texcoord=		IN.texcoord;
}


float4 default_ps(
	SCREEN_POSITION_INPUT(screen_position),
	in float2 texcoord : TEXCOORD0) : SV_Target
{
 	float4 color= sample2D(source_sampler, texcoord);
 	float4 color_to_nth=		pow(max(color.g, 0.00001), modulation_factor.y);			// gamma-enhanced monochrome channel to generate 'hot' white centers

 	float4 out_color=			modulation_factor.x*color_to_nth  +  color*tint_color;		// color tinted external areas for cool exterior

 	float brightness= tint_color.a*ILLUM_EXPOSURE*scale.r*modulation_factor.z;
 	return out_color*brightness;
}
