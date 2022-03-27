//#line 1 "source\rasterizer\hlsl\displacement.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define DISTORTION_MULTISAMPLED 1
#define LDR_ONLY 1


#include "shared\render_target.fx"


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif


#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define INT_CONSTANT(name, register_index)   int name : register(i##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#include "postprocess\displacement_registers.fx"


//@generate screen
sampler2D displacement_sampler : register(s0);
sampler2D ldr_buffer : register(s1);
#ifndef LDR_ONLY
sampler2D hdr_buffer : register(s2);
#endif


void default_vs(
	in vertex_type IN,
	out float4 position : POSITION,
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


float4 tex2D_unnormalized(sampler2D texture_sampler, float2 unnormalized_texcoord)
{
	float4 result;
	
#ifndef pc
	asm
	{
		tfetch2D result, unnormalized_texcoord, texture_sampler, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};
#else
	result= tex2D(texture_sampler, (unnormalized_texcoord + 0.5f) * screen_constants.xy);
#endif

	return result;
}


accum_pixel default_ps(
    in float4 iterator0 : TEXCOORD0)
{
    // unpack iterators
    float2 pixel_coords= iterator0.xy;
    float2 texture_coords= iterator0.zw;

    float2 displacement= tex2D(displacement_sampler, texture_coords).xy * distort_constants.xy + distort_constants.zw;

    float change= dot(displacement, displacement) - 0.001f;

    clip(change);                   // save the texture fetches and the frame buffer write

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
      displaced_pixel.color.rgb= 16 * displaced_pixel.color.rgb;
    }
    return displaced_pixel;
}
