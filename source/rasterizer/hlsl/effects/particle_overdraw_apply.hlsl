//#line 2 "source\rasterizer\hlsl\particle_overdraw_apply.hlsl"

#define POSTPROCESS_COLOR

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture.fx"
//@generate screen

sampler2D source_sampler : register(s0);


// pixel blur width (must be a multilpe of 0.5)
#define DELTA 0.5


float4 default_ps(screen_output IN) : COLOR
{
	float4 color;
#ifdef pc
 	color= tex2D(source_sampler, IN.texcoord);
#else // xenon
//	color= tex2D_bspline_fast_2x(source_sampler, IN.texcoord);
// 	color= tex2D(source_sampler, IN.texcoord);

	float2 texcoord0= IN.texcoord + pixel_size.xy * 0.25f;
	float2 texcoord1= IN.texcoord - pixel_size.xy * 0.25f;
	float4 tex0, tex1;
	asm
	{
//		tfetch2D tex0, texcoord, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled, OffsetX= +DELTA, OffsetY= +DELTA
//		tfetch2D tex1, texcoord, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled, OffsetX= -DELTA, OffsetY= -DELTA
		tfetch2D tex0, texcoord0, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
		tfetch2D tex1, texcoord1, source_sampler, MagFilter = linear, MinFilter = linear, MipFilter = point, AnisoFilter = disabled
	};
	color.rgb= (tex0.rgb + tex1.rgb) * 0.5f;
//	color.rgb= min(tex0.rgb, tex1.rgb);

//	color.a= min(tex0.a, tex1.a) * 0.75f + (tex0.a + tex1.a) * 0.125f;		// this results in a slightly lighter edge darkening than a straight 'min' function
	color.a= (tex0.a + tex1.a) * 0.5f;

#endif	
 	return color*scale;
}
