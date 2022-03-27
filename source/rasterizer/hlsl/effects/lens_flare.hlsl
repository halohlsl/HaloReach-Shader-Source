//#line 2 "source\rasterizer\hlsl\lens_flare.hlsl"

#define POSTPROCESS_COLOR
#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "hlsl_constant_globals.fx"
//@generate screen

sampler2D source_sampler : register(s0);

// x is modulation factor, y is tint power, z is brightness, w unused
PIXEL_CONSTANT(float4, modulation_factor, c50);
PIXEL_CONSTANT(float4, tint_color, c51);
PIXEL_CONSTANT( float4, scale, c2);
VERTEX_CONSTANT(float4, center_rotation, c240);		// center(x,y), theta
VERTEX_CONSTANT(float4, flare_scale, c241);			// scale(x, y), global scale
void default_vs(
	vertex_type IN,
	out float4 position : POSITION,
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
	in float2 texcoord : TEXCOORD0) : COLOR
{
 	float4 color=				tex2D(source_sampler, texcoord);
 	float4 color_to_nth=		pow(color.g, modulation_factor.y);			// gamma-enhanced monochrome channel to generate 'hot' white centers
 	
 	float4 out_color=			modulation_factor.x*color_to_nth  +  color*tint_color;		// color tinted external areas for cool exterior
	
 	float brightness= tint_color.a*ILLUM_EXPOSURE*scale.r*modulation_factor.z;
 	return out_color*brightness;
}
