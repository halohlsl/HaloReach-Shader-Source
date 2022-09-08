//#line 2 "source\rasterizer\hlsl\double_gradient.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
 	float4 color= sample2D(source_sampler, IN.texcoord);
#else
	float4 color_o, color_px, color_nx, color_py, color_ny;
	float2 texcoord= IN.texcoord;
#ifdef xenon
	asm
	{
		tfetch2D color_o, texcoord, source_sampler, OffsetX= 0, OffsetY= 0
		tfetch2D color_px, texcoord, source_sampler, OffsetX= 1, OffsetY= 0
		tfetch2D color_py, texcoord, source_sampler, OffsetX= 0, OffsetY= 1
		tfetch2D color_nx, texcoord, source_sampler, OffsetX= -1, OffsetY= 0
		tfetch2D color_ny, texcoord, source_sampler, OffsetX= 0, OffsetY= -1
	};
#else
	color_o = source_sampler.t.Sample(source_sampler.s, texcoord, int2(0, 0));
	color_px = source_sampler.t.Sample(source_sampler.s, texcoord, int2(1, 0));
	color_py = source_sampler.t.Sample(source_sampler.s, texcoord, int2(0, 1));
	color_nx = source_sampler.t.Sample(source_sampler.s, texcoord, int2(-1, 0));
	color_ny = source_sampler.t.Sample(source_sampler.s, texcoord, int2(0, -1));
#endif
	float4 laplacian_x= (color_px + color_nx - 2 * color_o);
	float4 laplacian_y= (color_py + color_ny - 2 * color_o);

	float4 gradient_magnitude= sqrt(laplacian_x * laplacian_x + laplacian_y * laplacian_y);
	float4 color= gradient_magnitude;
#endif
	return float4(saturate(color.rgb)*scale.rgb, scale.a);
}
