//#line 2 "source\rasterizer\hlsl\vertical_gaussian_blur.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D target_sampler : register(s0);

float4 default_ps(screen_output IN) : COLOR
{
	float2 sample= IN.texcoord;

//	sample.y= sample0.y - 4.5 * source_pixel_size.y;
//	sample.x += source_pixel_size.x / 2;

	sample.y -= 5.0 * pixel_size.y;	// -5
	float3 color= (1/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// -4
	color += (10/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// -3
	color += (45/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// -2
	color += (120/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// -1
	color += (210/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// 0
	color += (252/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// +1
	color += (210/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// +2
	color += (120/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// +3
	color += (45/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// +4
	color += (10/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	sample.y += pixel_size.y;			// +5
	color += (1/1024.0) *convert_from_bloom_buffer(tex2D(target_sampler, sample));

	return convert_to_bloom_buffer(color);
}
