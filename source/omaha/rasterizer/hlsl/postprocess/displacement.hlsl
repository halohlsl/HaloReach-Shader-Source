//#line 1 "source\rasterizer\hlsl\displacement.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#ifdef xenon
#define DISTORTION_MULTISAMPLED 1
#else
#define DISTORTION_MULTISAMPLED 0
#endif
#define LDR_ONLY 1

#include "shared\render_target.fx"
#include "postprocess\displacement_registers.fx"


//@generate screen
LOCAL_SAMPLER_2D(displacement_sampler, 0);
LOCAL_SAMPLER_2D(ldr_buffer, 1);
#ifndef LDR_ONLY
LOCAL_SAMPLER_2D(hdr_buffer, 2);
#endif


void default_vs(
	in vertex_type IN,
	out float4 position : SV_Position,
	out float4 iterator0 : TEXCOORD0)
{
    position.xy= IN.position;
    position.zw= 1.0f;

	float2 uncentered_texture_coords= position.xy * float2(0.5f, -0.5f) + 0.5f;				// uncentered means (0, 0) is the center of the upper left pixel
	float2 pixel_coords=	uncentered_texture_coords * vs_resolution_constants.xy + 0.5f;	// pixel coordinates are centered [0.5, resolution-0.5]
	float2 texture_coords=	uncentered_texture_coords + 0.5f * vs_resolution_constants.zw;	// offset half a pixel to center these texture coordinates

	iterator0.xy= pixel_coords;
	iterator0.zw= texture_coords;
}


float4 tex2D_unnormalized(texture_sampler_2d texture_sampler, float2 unnormalized_texcoord)
{
	float4 result;

#ifdef xenon
	asm
	{
		tfetch2D result, unnormalized_texcoord, texture_sampler, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};
#elif DX_VERSION == 11
    result= texture_sampler.t.Load(int3(unnormalized_texcoord, 0));
#else
	result= tex2D(texture_sampler, (unnormalized_texcoord + 0.5f) * screen_constants.xy);
#endif

	return result;
}


accum_pixel default_ps(
    SCREEN_POSITION_INPUT(screen_position),
    in float4 iterator0 : TEXCOORD0)
{
    // unpack iterators
    float2 pixel_coords= iterator0.xy;
    float2 texture_coords= iterator0.zw;

    float2 displacement= sample2D(displacement_sampler, texture_coords).xy * distort_constants.xy + distort_constants.zw;

#ifdef xenon
    float change= dot(displacement, displacement) - 0.001f;

    clip(change);                   // save the texture fetches and the frame buffer write
#else
    float change= 1.0f; // always do the displacement on non-xenon systems because they are using a double buffered render target
#endif

    accum_pixel displaced_pixel;
    displaced_pixel.color= 0.0f;

#ifdef xenon
    [branch]
    [ifAny]
#endif // xenon
    if (change > 0.0f)
    {
      pixel_coords += displacement;

      displaced_pixel.color= tex2D_unnormalized(ldr_buffer, pixel_coords);
#ifdef xenon
      displaced_pixel.color.rgb= 16 * displaced_pixel.color.rgb;
#endif
    }
    return displaced_pixel;
}
