//#line 2 "source\rasterizer\hlsl\crop.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
//@generate screen

sampler2D source_sampler : register(s0);

// returns black outside of the rectangle (in texture coordinate space:)
//
//    x in [scale.x, scale.z)
//    y in [scale.y, scale.w)
//
// essentially, scale is (left, top, right, bottom)
// left and top are inclusive, right and bottom are exclusive
//

PIXEL_CONSTANT( float4, texcoord_xform,		POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);
PIXEL_CONSTANT( float4, crop_bounds,		POSTPROCESS_EXTRA_PIXEL_CONSTANT_1);

float4 default_ps(screen_output IN) : COLOR
{
	float2 texcoord= transform_texcoord(IN.texcoord, texcoord_xform);
 	float4 color= tex2D(source_sampler, texcoord);
 	float crop= step(crop_bounds.x, texcoord.x) * step(texcoord.x, crop_bounds.z) * step(crop_bounds.y, texcoord.y) * step(texcoord.y, crop_bounds.w);
 	return color * scale * crop;
}
