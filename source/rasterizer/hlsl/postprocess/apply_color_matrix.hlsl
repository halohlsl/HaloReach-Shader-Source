//#line 2 "source\rasterizer\hlsl\rotate_2d.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "postprocess\apply_color_matrix_registers.fx"

//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);


// pixel fragment entry points
float4 default_ps(screen_output IN) : SV_Target
{
	float4 color= sample2D(source_sampler, IN.texcoord);

	float4 dest_color;
	dest_color.r= dot(dest_red.rgba,	color.rgba);
	dest_color.g= dot(dest_green.rgba,	color.rgba);
	dest_color.b= dot(dest_blue.rgba,	color.rgba);
	dest_color.a= dot(dest_alpha.rgba,	color.rgba);

	return dest_color;
}
