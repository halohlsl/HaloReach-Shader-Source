//#line 2 "source\rasterizer\hlsl\copy_surface.hlsl"

#define POSTPROCESS_COLOR

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen
//@entry default
//@entry depth_to_rgba_pack

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target
{
 	float4 color= sample2D(source_sampler, IN.texcoord);
 	color*= IN.color;
 	return color*scale;
}

screen_output depth_to_rgba_pack_vs(in vertex_type IN)
{
	return default_vs(IN);
}

// to be able copy D32_FLOAT surface into A8R8G8B8 surface
float4 depth_to_rgba_pack_ps(screen_output IN) : SV_Target
{
	// I expect to sample here the viewport space hyperbolic depth
	// then expect a value in the [0..1) range
	float depth = sample2D(source_sampler, IN.texcoord).r;

	float4 encoded = float4(1.f, 255.f, 65025.f, 16581375.f) * depth;

	encoded = frac(encoded);

	encoded -= encoded.yzww * float4(1.f / 255.f, 1.f / 255.f, 1.f / 255.f, 0.f);

	return encoded;
}
