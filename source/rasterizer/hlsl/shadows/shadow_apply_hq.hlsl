//#line 2 "source\rasterizer\hlsl\shadow_apply_fancy.hlsl"

//@generate tiny_position

#define FASTER_SHADOWS

#define SAMPLE_PERCENTAGE_CLOSER sample_percentage_closer_PCF_9x9_block_predicated
float sample_percentage_closer_PCF_9x9_block_predicated(float3 fragment_shadow_position, float depth_bias);

#include "shadows\shadow_apply.hlsl"

float sample_percentage_closer_PCF_9x9_block_predicated(float3 fragment_shadow_position, float depth_bias)
{
//#if DX_VERSION == 9
	const float half_texel_offset = 0.5f;
//#elif DX_VERSION == 11
//	const float half_texel_offset = 0.0f;
//#endif

	float2 texel1= fragment_shadow_position.xy;

	float4 blend;
#ifdef pc
   float2 frac_pos = fragment_shadow_position.xy / pixel_size + half_texel_offset;
   blend.xy = frac(frac_pos);
#else
#ifndef VERTEX_SHADER
//	fragment_shadow_position.xy += 0.5f;
	asm {
		getWeights2D blend.xy, fragment_shadow_position.xy, shadow, MagFilter=linear, MinFilter=linear
	};
#endif
#endif
	blend.zw= 1.0f - blend.xy;

#define offset_0 (-4.0f + half_texel_offset)
#define offset_1 (-3.0f + half_texel_offset)
#define offset_2 (-2.0f + half_texel_offset)
#define offset_3 (-1.0f + half_texel_offset)
#define offset_4 (-0.0f + half_texel_offset)
#define offset_5 (-1.0f + half_texel_offset)
#define offset_6 (+2.0f + half_texel_offset)
#define offset_7 (+3.0f + half_texel_offset)

	float3 max_depth= depth_bias;							// x= central samples,   y = adjacent sample,   z= diagonal sample
	max_depth *= float3(-2.0f, -sqrt(5.0f), -4.0f);			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	// 8x8 point and 7x7 bilinear
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow, texel1, offset_0, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_1, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_2, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_3, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_4, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_5, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_6, offset_0).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow, texel1, offset_7, offset_0).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_1).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_1).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_2).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_2).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_3).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_3).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_3).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_4).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_4).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_4).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_5).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_5).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_5).r) +

					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_0, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_1, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_2, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_3, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_4, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_5, offset_6).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel1, offset_6, offset_6).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_7, offset_6).r) +

					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow, texel1, offset_0, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_1, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_2, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_3, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_4, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_5, offset_7).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel1, offset_6, offset_7).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow, texel1, offset_7, offset_7).r);

	color /= 49.0f;

	return color;
}
