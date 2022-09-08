//#line 2 "source\rasterizer\hlsl\pixel_copy.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN, SCREEN_POSITION_INPUT(vpos)) : SV_Target
{
#ifdef pc
 	return sample2D(source_sampler, IN.texcoord * scale.xy);
 #else

	// wrap at 8x8
//	vpos= vpos - 8.0 * floor(vpos / 8.0);

	float2 texcoord=	IN.texcoord * scale.xy;

	float4 result;
	asm {
		tfetch2D result, texcoord, source_sampler, UnnormalizedTextureCoords=false, MagFilter=point, MinFilter=point, MipFilter=point, AnisoFilter=disabled
	};
	return result;
 #endif
}
