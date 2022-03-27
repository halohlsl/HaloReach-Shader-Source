//#line 2 "source\rasterizer\hlsl\double_gradient.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
#ifdef pc
 	float4 color= tex2D(source_sampler, IN.texcoord);
 #else
	float4 color_o, color_px, color_nx, color_py, color_ny;
	float2 texcoord= IN.texcoord;
	asm
	{
		tfetch2D color_o, texcoord, source_sampler, OffsetX= 0, OffsetY= 0
		tfetch2D color_px, texcoord, source_sampler, OffsetX= 1, OffsetY= 0
		tfetch2D color_py, texcoord, source_sampler, OffsetX= 0, OffsetY= 1
		tfetch2D color_nx, texcoord, source_sampler, OffsetX= -1, OffsetY= 0
		tfetch2D color_ny, texcoord, source_sampler, OffsetX= 0, OffsetY= -1
	};
	float4 laplacian_x= (color_px + color_nx - 2 * color_o);
	float4 laplacian_y= (color_py + color_ny - 2 * color_o);
	
	float4 gradient_magnitude= sqrt(laplacian_x * laplacian_x + laplacian_y * laplacian_y);
	float4 color= gradient_magnitude;
#endif
	return float4(saturate(color.rgb)*scale.rgb, scale.a);
}
