//#line 2 "source\rasterizer\hlsl\rotate_2d.hlsl"

//#define USE_CUSTOM_POSTPROCESS_CONSTANTS

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);
sampler2D background_sampler : register(s1);
PIXEL_CONSTANT( float2, offset, POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);

// pixel fragment entry points
float4 default_ps(screen_output IN) : COLOR
{
	float2 rotated_texcoord;
	rotated_texcoord.x= dot(scale.xy, IN.texcoord.xy) + offset.x;
	rotated_texcoord.y= dot(scale.zw, IN.texcoord.xy) + offset.y;
	
	float4 source=		tex2D(source_sampler,			rotated_texcoord);

	float4 background;
#ifdef pc
	background=	tex2D(background_sampler, IN.texcoord);
#else
	background= tex2D_offset_point(background_sampler, IN.texcoord, 0.0f, 0.0f);
#endif

	return background + source;
}
