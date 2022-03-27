//#line 2 "source\rasterizer\hlsl\update_persistence.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);
sampler2D previous_sampler : register(s1);

// how fast the persistence fades.  0.05 is about as slow as you want to go, and higher numbers fade faster
#define k_persistent_fadeout_speed 0.8

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	float2 sample0= IN.texcoord; // - 0.5 * source_pixel_size;

 	float3 color= convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += 2*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += 2*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
	
	sample0.x -= pixel_size.x*2;
	sample0.y += pixel_size.y;
	color += 2*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += 4*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
	color += (k_persistent_fadeout_speed * 16) * convert_from_bloom_buffer(tex2D(source_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += 2*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));

	sample0.x -= pixel_size.x*2;
	sample0.y += pixel_size.y;
	color += convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += 2*convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
 	sample0.x += pixel_size.x;
	color += convert_from_bloom_buffer(tex2D(previous_sampler, sample0));
	
	color= color / (16 * (1.0 + k_persistent_fadeout_speed));

	return convert_to_bloom_buffer(color);
}
