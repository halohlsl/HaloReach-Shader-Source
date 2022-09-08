//#line 2 "source\rasterizer\hlsl\antialias_blur_combine.hlsl"

#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
#include "shared\texture_xform.fx"
#include "postprocess\antialias_blur_combine_registers.fx"
//@generate screen

void default_vs(
	in vertex_type IN,
	out float4 position : SV_Position,
	out float4 texcoord : TEXCOORD0)
{
	texcoord.xy=		transform_texcoord(IN.texcoord, vs_texcoord_xform0);
	texcoord.zw=		transform_texcoord(IN.texcoord, vs_texcoord_xform1);

	position.xy=		IN.position;
	position.zw=		1.0f;
}

#ifdef xenon

#define tfetch(color, texcoord, sampler, offsetx, offsety)																																	\
		asm																																													\
		{																																													\
			tfetch2D	color,	texcoord,	sampler,	MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX=  offsetx, OffsetY=  offsety					\
		};																																													\
		color.rgb	*=	color.rgb;

#elif DX_VERSION == 11

#define tfetch(color, texcoord, sampler, offsetx, offsety)							\
		color= sampler.t.Sample(sampler.s, texcoord, int2(offsetx, offsety));		\
		color.rgb	*=	color.rgb;

#endif

float4 default_ps(in float4 texcoord : TEXCOORD0) : SV_Target
{
	// ###ctchou $TODO drop this transform, we can use the offsetX, offsetY fetching
	float2 texcoord0=	texcoord.xy;		// transform_texcoord(IN.texcoord, texcoord_xform0);
	float2 texcoord1=	texcoord.zw;		// transform_texcoord(IN.texcoord, texcoord_xform1);

#if defined(pc) && (DX_VERSION == 9)
 	float4 color0= tex2D(source_sampler0, texcoord0);	// centered sample
 	float4 color1= tex2D(source_sampler1, texcoord1);	// offset sample

	// linearize values
	float4 linear0= float4(exp2(color0.rgb * 8.0f - 8.0f), color0.a);
	float4 linear1= float4(exp2(color1.rgb * 8.0f - 8.0f), color1.a);

 #else

	float4	linear1;
	{
//*
		float4 temp;
		tfetch(linear1, texcoord1, source_sampler1,  0.5f,  0.5f);
		tfetch(temp,	texcoord1, source_sampler1, -0.5f,  0.5f);
			linear1.rgb	+=	temp.rgb;
			linear1.a	=	max(linear1.a, temp.a);
		tfetch(temp,	texcoord1, source_sampler1, -0.5f, -0.5f);
			linear1.rgb	+=	temp.rgb;
			linear1.a	=	max(linear1.a, temp.a);
		tfetch(temp,	texcoord1, source_sampler1,  0.5f, -0.5f);
			linear1.rgb	+=	temp.rgb;
			linear1.a	=	max(linear1.a, temp.a);
		linear1.rgb	*=	0.25f;
/*/
		linear1=		tex2D(source_sampler1, texcoord1);
		linear1 *= linear1;
//*/
	}

	float4	linear0;
	tfetch(linear0, texcoord0, source_sampler0, 0.0f, 0.0f);

#endif


	// scale.xy is the centered/offset weights for a fully antialiased pixel (which we want when the pixel is expected to be relatively stationary)
	// scale.zw is the centered/offset weights for a non-antialiased pixel (which we want when the pixel is expected to be moving quickly)
	// we blend between the two based on our expected velocity

	float min_velocity=			max(linear0.a, linear1.a);
	float expected_velocity=	min_velocity;								// if we write estimated velocity into the alpha channel, we can use them here
	float2 weights=				lerp(scale.xy, scale.zw, expected_velocity);

	float3 linear_blend=		weights.x * linear0 + weights.y * linear1;			// ###ctchou $PERF might be able to optimize this by playing around with the log space..  maybe

	float3 final_blend=			sqrt(linear_blend);

 	return float4(final_blend, expected_velocity);

}
