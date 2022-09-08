//#line 2 "source\rasterizer\hlsl\downsample_4x4_gaussian.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

LOCAL_SAMPLER_2D(source_sampler, 0);

float4 default_ps(screen_output IN) : SV_Target				// ###ctchou $TODO $PERF convert this to tex2D_offset, and do a gaussian filter greater than 4x4 kernel (cheap cuz we only use it on the smaller size textures)
{
#ifdef pc
	float4 color= 0.00000001f;			// hack to keep divide by zero from happening on the nVidia cards
#else
	float4 color= 0.0f;
#endif
/*
	// this is a 6x6 gaussian filter (slightly better than 4x4 box filter)
	color += (0.25f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, -2, -2);
	color += (0.50f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +0, -2);
	color += (0.25f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +2, -2);
	color += (0.50f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, -2, +0);
	color += (1.00f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +0, +0);
	color += (0.50f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +2, +0);
	color += (0.25f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, -2, +2);
	color += (0.50f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +0, +2);
	color += (0.25f * 0.25f) * tex2D_offset(source_sampler, IN.texcoord, +2, +2);
/*/

/*
	float	c0=		(3.0f / 8.0f);
	float	c1=		(7.0f / 56.0f);

	float4	coord11=	IN.texcoord.xyxy + pixel_size.xyxy * float4(-c0, -c0, c0, c0);
	float4	coord33=	IN.texcoord.xyxy + pixel_size.xyxy * float4(-c1, -c1, c1, c1);
	float4	coord13=	IN.texcoord.xyxy + pixel_size.xyxy * float4(-c0, -c1, c0, c1);
	float4	coord31=	IN.texcoord.xyxy + pixel_size.xyxy * float4(-c1, -c0, c1, c0);

	// 8x8 gaussian
	color += (0.125f * 0.125f) * tex2D_offset(source_sampler, coord33.zw, -3, -3);
	color += (0.375f * 0.125f) * tex2D_offset(source_sampler, coord13.zw, -1, -3);
	color += (0.375f * 0.125f) * tex2D_offset(source_sampler, coord13.xw, +1, -3);
	color += (0.125f * 0.125f) * tex2D_offset(source_sampler, coord33.xw, +3, -3);

	color += (0.125f * 0.375f) * tex2D_offset(source_sampler, coord31.zw, -3, -1);
	color += (0.375f * 0.375f) * tex2D_offset(source_sampler, coord11.zw, -1, -1);
	color += (0.375f * 0.375f) * tex2D_offset(source_sampler, coord11.xw, +1, -1);
	color += (0.125f * 0.375f) * tex2D_offset(source_sampler, coord31.xw, +3, -1);

	color += (0.125f * 0.375f) * tex2D_offset(source_sampler, coord31.zy, -3, +1);
	color += (0.375f * 0.375f) * tex2D_offset(source_sampler, coord11.zy, -1, +1);
	color += (0.375f * 0.375f) * tex2D_offset(source_sampler, coord11.xy, +1, +1);
	color += (0.125f * 0.375f) * tex2D_offset(source_sampler, coord31.xy, +3, +1);

	color += (0.125f * 0.125f) * tex2D_offset(source_sampler, coord33.zy, -3, +3);
	color += (0.375f * 0.125f) * tex2D_offset(source_sampler, coord13.zy, -1, +3);
	color += (0.375f * 0.125f) * tex2D_offset(source_sampler, coord13.xy, +1, +3);
	color += (0.125f * 0.125f) * tex2D_offset(source_sampler, coord33.xy, +3, +3);
*/

	// Multiply by 2 ^ 3 to match Xenon tex2D data
	float2	coord=	IN.texcoord.xy;

	color += tex2D_offset(source_sampler, coord, -3, -3) * 8;
	color += tex2D_offset(source_sampler, coord, -1, -3) * 8;
	color += tex2D_offset(source_sampler, coord, +1, -3) * 8;
	color += tex2D_offset(source_sampler, coord, +3, -3) * 8;

	color += tex2D_offset(source_sampler, coord, -3, -1) * 8;
	color += tex2D_offset(source_sampler, coord, -1, -1) * 8;
	color += tex2D_offset(source_sampler, coord, +1, -1) * 8;
	color += tex2D_offset(source_sampler, coord, +3, -1) * 8;

	color += tex2D_offset(source_sampler, coord, -3, +1) * 8;
	color += tex2D_offset(source_sampler, coord, -1, +1) * 8;
	color += tex2D_offset(source_sampler, coord, +1, +1) * 8;
	color += tex2D_offset(source_sampler, coord, +3, +1) * 8;

	color += tex2D_offset(source_sampler, coord, -3, +3) * 8;
	color += tex2D_offset(source_sampler, coord, -1, +3) * 8;
	color += tex2D_offset(source_sampler, coord, +1, +3) * 8;
	color += tex2D_offset(source_sampler, coord, +3, +3) * 8;

	color	*=	1.0f / 16.0f;

	// The output surface/texture on Xenon has a range of 0-8 and an additional exponent bias of -2
	color = min(color * 4, 8); // like in Xenon render-target
	color = color / 32; // like in Xenon "Resolve" texture

	return color;
}
