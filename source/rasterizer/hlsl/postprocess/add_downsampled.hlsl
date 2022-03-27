//#line 2 "source\rasterizer\hlsl\add_downsampled.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D downsampled_sampler : register(s0);		// pixel_size is the size of the pixels in this texture
sampler2D original_sampler : register(s1);			// but not necessarily this one

float3 get_pixel_bilinear(float2 tex_coord)
{
	tex_coord= (tex_coord / pixel_size) - 0.5;
	float2 texel0= floor(tex_coord);

	float4 blend;
	blend.xy= tex_coord - texel0;
	blend.zw= 1.0 - blend.xy;
	
	blend.xyzw= blend.zxzx * blend.wwyy;

	texel0= (texel0 + 0.5)* pixel_size;

	float2 texel1= texel0;
	texel1.x += pixel_size.x;

	float2 texel2= texel0;
	texel2.y += pixel_size.y;

	float2 texel3= texel2;
	texel3.x = texel1.x;

	float3 color=	blend.x * convert_from_bloom_buffer(tex2D(downsampled_sampler, texel0)) +
					blend.y * convert_from_bloom_buffer(tex2D(downsampled_sampler, texel1)) +
					blend.z * convert_from_bloom_buffer(tex2D(downsampled_sampler, texel2)) +
					blend.w * convert_from_bloom_buffer(tex2D(downsampled_sampler, texel3));

	return color;
}

float4 default_ps(screen_output IN) : COLOR
{
	float2 sample= IN.texcoord;

	float3 color= convert_from_bloom_buffer(tex2D(original_sampler, sample));
	color += scale * get_pixel_bilinear(sample);

	return convert_to_bloom_buffer(color);
}
