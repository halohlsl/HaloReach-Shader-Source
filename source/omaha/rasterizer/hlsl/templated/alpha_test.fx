#include "templated\entry.fx"


#define ALPHA_TEST(alpha_test) ALPHA_TEST_##alpha_test
#define ALPHA_TEST_off 0
#define ALPHA_TEST_on 1
#define ALPHA_TEST_multmap 2


PARAM_SAMPLER_2D(alpha_test_map);
PARAM(float4, alpha_test_map_xform);

float calc_alpha_test_off_ps(
	in float2 texcoord)
{
	return 1;
}

float calc_alpha_test_on_ps(
	in float2 texcoord)
{
	float alpha= sample2D(alpha_test_map, transform_texcoord(texcoord, alpha_test_map_xform)).a;

	clip(alpha-0.5f);			// always on for shadow
	
	return alpha;
}


float calc_alpha_test_off_post_albedo_ps(
	in float2 texcoord,
	in float4 albedo)
{
	return 1;
}


float calc_alpha_test_from_albedo_ps(
	in float2 texcoord,
	in float4 albedo)
{
	clip (albedo.a - 0.5f);
	return albedo.a;
}


float calc_alpha_test_texture_ps(
	in float2 texcoord,
	in float4 albedo)
{
	float alpha= sample2D(alpha_test_map, transform_texcoord(texcoord, alpha_test_map_xform)).a;

	clip(alpha-0.5f);			// always on for shadow
	
	return alpha;
}
