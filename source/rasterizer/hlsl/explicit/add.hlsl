//#line 2 "source\rasterizer\hlsl\add.hlsl"


#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


LOCAL_SAMPLER_2D(original_sampler, 0);
LOCAL_SAMPLER_2D(add_sampler, 1);


float4 default_ps(screen_output IN) : SV_Target
{
	// Multiply by 2 ^ 3 to match Xenon tex2D data
	float4 original= sample2D(original_sampler, IN.texcoord) * 8;
	float4 add= sample2D(add_sampler, IN.texcoord) * 8;

	float4 color;
	color.rgb= scale.rgb * original.rgb * add.a + add.rgb;
	color.a= add.a;
	// The output surface/texture on Xenon has a range of 0-8 and an additional exponent bias of -2
	color = min(color * 4, 8); // like in Xenon render-target
	color = color / 32; // like in Xenon "Resolve" texture
	return color;
}
