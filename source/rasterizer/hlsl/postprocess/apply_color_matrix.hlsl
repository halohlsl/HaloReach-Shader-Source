//#line 2 "source\rasterizer\hlsl\rotate_2d.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);
PIXEL_CONSTANT( float4, dest_red,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);
PIXEL_CONSTANT( float4, dest_green, POSTPROCESS_EXTRA_PIXEL_CONSTANT_1);
PIXEL_CONSTANT( float4, dest_blue,	POSTPROCESS_EXTRA_PIXEL_CONSTANT_2);
PIXEL_CONSTANT( float4, dest_alpha, POSTPROCESS_EXTRA_PIXEL_CONSTANT_3);

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	float4 color= tex2D(source_sampler, IN.texcoord);

	float4 dest_color;
	dest_color.r= dot(dest_red.rgba,	color.rgba);
	dest_color.g= dot(dest_green.rgba,	color.rgba);
	dest_color.b= dot(dest_blue.rgba,	color.rgba);
	dest_color.a= dot(dest_alpha.rgba,	color.rgba);

	return dest_color;
}
