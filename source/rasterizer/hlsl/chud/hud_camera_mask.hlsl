//#line 2 "source\rasterizer\hlsl\hud_camera_mask.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);
sampler2D color_sampler : register(s1);
sampler2D mask_sampler : register(s2);
float4 colors[4] : register(c100);

float4 default_ps(screen_output IN) : COLOR
{
#ifdef pc
 	float4 color= tex2D(source_sampler, IN.texcoord);
 #else

	float2 texcoord= IN.texcoord;
	float2 laplacian;
	
	[isolate]
	float4 alpha;
	{
		asm
		{
			tfetch2D alpha, texcoord, mask_sampler
		};
		if (alpha.a <= 0)
		{
			return float4(0.0f, 0.0f, 0.0f, 0.0f);
		}
	}
	
	[isolate]	
	{
		float4 color_px, color_nx;
		float4 color_py, color_ny;
		asm
		{
			tfetch2D color_px, texcoord, source_sampler, OffsetX= 1, OffsetY= 0
			tfetch2D color_nx, texcoord, source_sampler, OffsetX= -1, OffsetY= 0
			tfetch2D color_py, texcoord, source_sampler, OffsetX= 0, OffsetY= 1
			tfetch2D color_ny, texcoord, source_sampler, OffsetX= 0, OffsetY= -1
		};
		laplacian.x= (color_px.r + color_nx.r);
		laplacian.y= (color_py.r + color_ny.r);
	}

	{
		float4 color_o;
		asm
		{
			tfetch2D color_o, texcoord, source_sampler, OffsetX= 0, OffsetY= 0
		};	
		laplacian -= 2 * color_o.rr;
	}
	
	float4 gradient_magnitude= sqrt(dot(laplacian.xy, laplacian.xy)) * 100.0f;

	float4 color;
	asm
	{
		tfetch2D color, texcoord, color_sampler, OffsetX= 0, OffsetY= 0
	};
	
	// convert to [0..4]
	color= colors[floor(color.b * 4 + 0.5f)];
	color.rgb *= gradient_magnitude;
	color.a *= LDR_ALPHA_ADJUST;

	color.rgba *= alpha.a;

#endif
	return color;
}
