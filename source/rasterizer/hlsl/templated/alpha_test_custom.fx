
sampler		multiply_map;
float4		multiply_map_xform;

void calc_alpha_test_multiply_map_ps(
	in float2 texcoord)
{

	float4 alpha_test_layer=	tex2D(alpha_test_map,	transform_texcoord(texcoord,	alpha_test_map_xform));
	float4 multiply_layer=		tex2D(multiply_map,		transform_texcoord(texcoord,	multiply_map_xform));

	float alpha=		alpha_test_layer.a * multiply_layer.a;

	// output_alpha= alpha;
	// float alpha= tex2D(alpha_test_map, transform_texcoord(texcoord, alpha_test_map_xform)).a;
	clip(alpha-0.5f);
}
