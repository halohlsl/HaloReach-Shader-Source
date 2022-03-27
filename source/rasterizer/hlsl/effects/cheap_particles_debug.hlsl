//#line 2 "source\rasterizer\hlsl\copy.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D position_age_sampler : register(s0);
sampler2D parameters_sampler : register(s1);


float4 default_ps(screen_output IN) : COLOR
{
	float4	position_age=	0;
	float4	parameters=		0;
	float2	texcoord=		IN.texcoord.xy;

#ifdef xenon	
	asm
	{
		tfetch2D	position_age,
					texcoord,
					position_age_sampler,
					MagFilter=		point,
					MinFilter=		point,
					MipFilter=		point,
					AnisoFilter=	disabled
		tfetch2D	parameters,
					texcoord,
					parameters_sampler,
					MagFilter=		point,
					MinFilter=		point,
					MipFilter=		point,
					AnisoFilter=	disabled
	};
#endif

	float			type=		parameters.z * 255.0f * (1.0f / 7.2736f);
	
	float3			color=	float3(
										sin((type + 0.00f) * 6.28) * 0.5f + 0.5f,
										sin((type + 0.33f) * 6.28) * 0.5f + 0.5f,
										sin((type + 0.66f) * 6.28) * 0.5f + 0.5f
								);

	color=			normalize(color);

	float			age=	sqrt(saturate(1.0f - abs(position_age.a)));
	
	float4 result=	float4(color * age, 1.0f);
		
	if (scale.a <= 0.0f)
	{
		result=	float4(1.0f, 0.0f, 0.0f, 1.0f);
	}
		
 	return result;
}
