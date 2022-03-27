////#line 1 "source\rasterizer\hlsl\displacement_motion_blur.hlsl"

//
//   For future reference, this shader should have the following stats when compiled:
//
//    Cycles/64 pixel vector: ALU 10.67-45.33 (8-34 instructions), vertex 0, texture 4-32, sequencer 24, interpolator 8
//    5 GPRs, 60 threads,  Performance (if enough threads): ~24-46 cycles per vector
//

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
	#define INT_CONSTANT(name, register_index)   int name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define INT_CONSTANT(name, register_index)   int name : register(i##register_index);
#endif

#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#include "postprocess\displacement_registers.fx"


//@generate screen
sampler2D displacement_sampler : register(s0);
sampler2D ldr_buffer : register(s1);
#ifndef LDR_ONLY
sampler2D hdr_buffer : register(s2);
#endif


sampler2D distortion_depth_buffer : register(s3);



void default_vs(
	in vertex_type IN,
	out float4 position : POSITION,
	out float4 iterator0 : TEXCOORD0,
	out float4 iterator1 : TEXCOORD1)
{
    position.xy= IN.position;
    position.zw= 1.0f;

	float2 uncentered_texture_coords= position.xy * float2(0.5f, -0.5f) + 0.5f;				// uncentered means (0, 0) is the center of the upper left pixel
	float2 pixel_coords=	uncentered_texture_coords * vs_resolution_constants.xy + 0.5f;	// pixel coordinates are centered [0.5, resolution-0.5]
	float2 texture_coords=	uncentered_texture_coords + 0.5f * vs_resolution_constants.zw;	// offset half a pixel to center these texture coordinates
	
	iterator0.xy= pixel_coords;
	iterator0.zw= texture_coords;
	
	iterator1.xy= pixel_coords.xy * vs_crosshair_constants.xy + vs_crosshair_constants.zw; 
	iterator1.zw= 0.0f;
}


accum_pixel default_ps(
	in float4 iterator0 : TEXCOORD0,
	in float4 iterator1 : TEXCOORD1)
{
	// unpack iterators
	float2 pixel_coords= iterator0.xy;
	float2 texture_coords= iterator0.zw;
	float2 crosshair_relative_position= iterator1.xy;

	if (do_distortion)
	{
		float2 displacement= tex2D(displacement_sampler, texture_coords).xy * distort_constants.xy + distort_constants.zw;
		pixel_coords += displacement;
	}

#ifndef pc

	float4 center_color;
	asm {
		tfetch2D	center_color, pixel_coords.xy, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};

	float4 accum_color= float4(center_color.rgb, 1.0f/16.0f) * (1.0f / 32.0f);		// 1/16th is needed so that when we normalize accum_color at the bottom, it will be multiplied by 16

	//crosshair_relative_position= pixel_coords.xy * crosshair_constants.xy + crosshair_constants.zw;
	float center_falloff_scale_factor= saturate(dot(crosshair_relative_position.xy, crosshair_relative_position.xy));

    // this removes blur when HDR to stop HDR disappearance, but costs a decent amount of ALUs  :(
    #define TRANSITION_STEEPNESS (4.0f)

//    float intensity= dot(accum_color.rgb, float3(0.35f, 0.45f, 0.20f));
//    float combined_weight *= saturate(TRANSITION_STEEPNESS - intensity * (TRANSITION_STEEPNESS / (8.0f/16/32.0f/8.0f)));

    float4 intensity_scale=
    float4(
       -float3(0.35f, 0.45f, 0.20f) * TRANSITION_STEEPNESS / (8.0f/16/32.0f/8.0f),
       TRANSITION_STEEPNESS * (16.0f) * (32.0f)
    );
    float intensity= dot(accum_color.rgba, intensity_scale);
    float combined_weight= saturate(intensity);

    combined_weight *= saturate(center_color.a * 32.0f * center_falloff_scale_factor - 0.1f);
	
	if (combined_weight > 0.0f) 
	{
		// fetch depth
		float4 depth;
		asm
		{
			tfetch2D depth, pixel_coords, distortion_depth_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
		};
		
		// calculate pixel coordinate for this pixel in the previous frame
		float4 previous_pixel_coords= mul(float4(pixel_coords.xy, depth.x, 1.0f), transpose(combined3));
		previous_pixel_coords.xy /= previous_pixel_coords.w;
		
		// scale and clamp the pixel delta
		float2 pixel_delta= pixel_coords.xy - previous_pixel_coords.xy;
		float delta_length= sqrt(dot(pixel_delta, pixel_delta));			
		float scale= saturate(pixel_blur_constants.y / delta_length);
		
		// NOTE:  uv_delta.zw == 2 * uv_delta.xy    (the factor of 2 is stored in pixel_blur_constants.zw...  this is an optimization to save calculation later on)
		float4 uv_delta= pixel_blur_constants.zzww * pixel_delta.xyxy * scale * combined_weight;

		// the current pixel coordinates are offset by 1 and 2 deltas (we already have the original point sampled above)
		float4 current_pixel_coords= pixel_coords.xyxy + uv_delta.xyzw;
	
        uv_delta.x= 1.0f/32.0f;    
        uv_delta.y= 0.0f;

		{
			float4 sample0, sample1;
			
			// sample twice in each loop to minimize loop overhead
/*			for (int i = 0; i < 3; ++ i)
			{
				asm {
					tfetch2D	sample0, current_pixel_coords.xy, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					tfetch2D	sample1, current_pixel_coords.zw, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					add			current_pixel_coords, current_pixel_coords, uv_delta.zwzw
					mad			accum_color.rgb, sample0.rgb, sample0.a, accum_color.rgb
					mad			accum_color.rgb, sample1.rgb, sample1.a, accum_color.rgb
					add			accum_color.a, accum_color.a, sample0.a
					add			accum_color.a, accum_color.a, sample1.a
				};				
			}
*/			

			// manually unroll 3 times
			{
				[noExpressionOptimizations]
				[isolate]
				asm					// this formulation tricks the compiler into using the scalar/vector parallel structure and using only 6 instructions per 2 samples!
				{
					tfetch2D    sample0, current_pixel_coords.xy, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					tfetch2D    sample1, current_pixel_coords.zw, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					add         current_pixel_coords, current_pixel_coords, uv_delta.zwzw
					mad         accum_color.rgb, sample0.rgb, sample0.a, accum_color.rgb
					mad         accum_color.rgb, sample1.rgb, sample1.a, accum_color.rgb
					add         uv_delta.x, uv_delta.x, sample0.a
					add         uv_delta.y, uv_delta.y, sample1.a
				};
			}

			{
				[noExpressionOptimizations]
				[isolate]
				asm					// this formulation tricks the compiler into using the scalar/vector parallel structure and using only 6 instructions per 2 samples!
				{
					tfetch2D    sample0, current_pixel_coords.xy, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					tfetch2D    sample1, current_pixel_coords.zw, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					add         current_pixel_coords, current_pixel_coords, uv_delta.zwzw
					mad         accum_color.rgb, sample0.rgb, sample0.a, accum_color.rgb
					mad         accum_color.rgb, sample1.rgb, sample1.a, accum_color.rgb
					add         uv_delta.x, uv_delta.x, sample0.a
					add         uv_delta.y, uv_delta.y, sample1.a
				};
			}

			{
				[noExpressionOptimizations]
				[isolate]
				asm					// this formulation tricks the compiler into using the scalar/vector parallel structure and using only 6 instructions per 2 samples!
				{
					tfetch2D    sample0, current_pixel_coords.xy, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					tfetch2D    sample1, current_pixel_coords.zw, ldr_buffer, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
					add         current_pixel_coords, current_pixel_coords, uv_delta.zwzw
					mad         accum_color.rgb, sample0.rgb, sample0.a, accum_color.rgb
					mad         accum_color.rgb, sample1.rgb, sample1.a, accum_color.rgb
					add         uv_delta.x, uv_delta.x, sample0.a
					add         uv_delta.y, uv_delta.y, sample1.a
				};
			}
		
			accum_color.a= dot(uv_delta.xy, 1.0f/16.0f);		// handles multiplying final result by 16 as well
		}
	}
	
	accum_pixel displaced_pixel;
	displaced_pixel.color.rgb= accum_color.rgb / accum_color.a;
	displaced_pixel.color.a= 0.0f;

	// 12 ALUs:		linear/16 -> 7e3
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/64.0f);		// exponent [0,1] (default)	and [2]
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/32.0f);		// exponent [3]
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/16.0f);		// exponent [4]		// this is enough for LDR, but we must reconstruct HDR for bloom...
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/8.0f);		// exponent [5]
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/4.0f);		// exponent [6]
//	displaced_pixel.color.rgb= max(displaced_pixel.color.rgb, displaced_pixel.color.rgb * 2 - 1/2.0f);		// exponent [7]

	// Perform the 7e3 conversion.  Note that this varies on the value of e for each channel:
	// if e != 0.0f then the correct conversion is (1+m)/8*pow(2,e).
	// else it is (1+m)/8*pow(2,e).  
	// Note that 2^0 = 1 so we can reduce this more.
	// Removing the /8 and putting it inside the pow() does not save instructions		

//	displaced_pixel.color.rgb *=	8.0f*16.0f;
//	float3 e=	floor(displaced_pixel.color.rgb);		// [0-8]
//	float3 m=	frac(displaced_pixel.color.rgb);		// [0-1]
//	displaced_pixel.color.rgb=	(e == 0.0f) ? m/4 : (1+m)/8 * exp2(e);

//	displaced_pixel.color.rgb *= 16;					// INSTEAD OF MULTIPLYING HERE, WE BUILD A FACTOR OF 1/16th INTO accum_color.a BY THE FINAL DOT PRODUCT (OR INITIALIZATION)

#else // pc
	accum_pixel displaced_pixel;
	displaced_pixel.color= 0;
#endif // pc

	return displaced_pixel;
}
