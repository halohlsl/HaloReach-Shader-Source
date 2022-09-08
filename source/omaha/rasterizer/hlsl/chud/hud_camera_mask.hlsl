//#line 2 "source\rasterizer\hlsl\hud_camera_mask.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "chud\hud_camera_mask_registers.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);
LOCAL_SAMPLER_2D(color_sampler, 1);
LOCAL_SAMPLER_2D(mask_sampler, 2);

float4 default_ps(screen_output IN) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
 	float4 color= tex2D(source_sampler, IN.texcoord);
#else

	float2 texcoord= IN.texcoord;
	float2 laplacian;

	[isolate]
	float4 alpha;
	{
#ifdef xenon
		asm
		{
			tfetch2D alpha, texcoord, mask_sampler
		};
#else
		alpha = sample2D(mask_sampler, texcoord);
#endif
		if (alpha.a <= 0)
		{
			return float4(0.0f, 0.0f, 0.0f, 0.0f);
		}
	}

	[isolate]
	{
		float4 color_px, color_nx;
		float4 color_py, color_ny;
#ifdef xenon
		asm
		{
			tfetch2D color_px, texcoord, source_sampler, OffsetX= 1, OffsetY= 0
			tfetch2D color_nx, texcoord, source_sampler, OffsetX= -1, OffsetY= 0
			tfetch2D color_py, texcoord, source_sampler, OffsetX= 0, OffsetY= 1
			tfetch2D color_ny, texcoord, source_sampler, OffsetX= 0, OffsetY= -1
		};
#else
		color_px = source_sampler.t.Sample(source_sampler.s, texcoord, int2(1, 0));
		color_nx = source_sampler.t.Sample(source_sampler.s, texcoord, int2(-1, 0));
		color_py = source_sampler.t.Sample(source_sampler.s, texcoord, int2(0, 1));
		color_ny = source_sampler.t.Sample(source_sampler.s, texcoord, int2(0, -1));
#endif
		laplacian.x= (color_px.r + color_nx.r);
		laplacian.y= (color_py.r + color_ny.r);
	}

	{
		float4 color_o;
#ifdef xenon
		asm
		{
			tfetch2D color_o, texcoord, source_sampler, OffsetX= 0, OffsetY= 0
		};
#else
		color_o = sample2D(source_sampler, texcoord);
#endif
		laplacian -= 2 * color_o.rr;
	}

	float4 gradient_magnitude= sqrt(dot(laplacian.xy, laplacian.xy)) * 100.0f;

	float4 color;
#ifdef xenon
	asm
	{
		tfetch2D color, texcoord, color_sampler, OffsetX= 0, OffsetY= 0
	};
#else
	color = sample2D(color_sampler, texcoord);
#endif

	// convert to [0..4]
	color= colors[floor(color.b * 4 + 0.5f)];
	color.rgb *= gradient_magnitude;
	color.a *= LDR_ALPHA_ADJUST;

	color.rgba *= alpha.a;

#endif
	return color;
}
