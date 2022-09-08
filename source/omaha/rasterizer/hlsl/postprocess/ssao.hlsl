//#line 2 "source\rasterizer\hlsl\ssao.hlsl"

// TODO - make sure this uses the same scale / sample_position_offset parameters to make it work in split screen / screenshot mode (when tiling)

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"

#define FLT_MAX         3.402823466e+38F

//............................................................................................................................................................
//This comment causes the shader compiler to be invoked for certain vertex types
//@generate screen
//............................................................................................................................................................

//............................................................................................................................................................
//These comments below cause the shader compiler to be invoked for certain entry points
//@entry default
//@entry albedo
//@entry static_sh
//@entry shadow_apply
//@entry single_pass_single_probe
//............................................................................................................................................................


// Uncomment to enable high quality depth-aware upsampling of SSAO data to shadow mask. However this method currently creates occlusion around really
// steep depth discontinuities, such as around the border of a building along the sky box. That needs to be modified.
//#define UPSAMPLE_SSAO_HIGH_QUALITY

//............................................................................................................................................................
// Setup entry points mapping for HLSL
//............................................................................................................................................................
#define compute_ssao_vs 					default_vs					// the default entry point gets used for main SSAO shader computation
#define compute_ssao_ps 					default_ps

#define downsample_normals_vs				albedo_vs					// the albedo entry point gets used for downsampling normals
#define downsample_normals_ps 				albedo_ps

#define compute_ssao_horizontal_blur_vs		static_sh_vs				// the static_sh entry point gets used for the horizontal SSAO blur pass
#define compute_ssao_horizontal_blur_ps 	static_sh_ps

#define compute_ssao_vertical_blur_vs		shadow_apply_vs				// the shadow apply entry point gets used for the vertical SSAO blur pass
#define compute_ssao_vertical_blur_ps		shadow_apply_ps

#define upsample_ssao_and_apply_vs			single_pass_single_probe_vs	// the single probe entry point gets used for upsampling and applying SSAO to shadow mask texture
#define upsample_ssao_and_apply_ps			single_pass_single_probe_ps

//................................................
// Float constants:
//................................................

#define FLOAT_CONSTANT_NAME(n) c##n
#define INT_CONSTANT_NAME(n)   i##n

#include "postprocess\postprocess_registers.fx"
#include "postprocess\ssao_registers.fx"
#include "hlsl_constant_globals.fx"


//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Shader input and output structures
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
struct screen_output_ssao
{
	float4 position				 :SV_Position;
	float2 texcoord				 :TEXCOORD0;
	float2 position_screen_space :TEXCOORD1;
};

struct screen_input_ssao
{
	float4 position				 :SV_Position;
	float2 texcoord				 :TEXCOORD0;
	float2 position_screen_space :TEXCOORD1;
};

struct screen_output
{
	float4 position		:SV_Position;
	float2 texcoord		:TEXCOORD0;
};


struct screen_input
{
	float4 position		:SV_Position;
	float2 texcoord		:TEXCOORD0;
};

//.............................................................................................................................................................
//.............................................................................................................................................................
//
//															Screen-space directional occlusion computation
//
//.............................................................................................................................................................
//.............................................................................................................................................................

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Vertex shader for a full-screen quad pass
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
screen_output_ssao compute_ssao_vs(vertex_type IN)
{
	screen_output_ssao OUT;

	OUT.texcoord=	 			  IN.texcoord;
	OUT.position.xy= 			  IN.position;
	OUT.position.zw=			  1.0f;
	OUT.position_screen_space.xy= IN.position;

	return OUT;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method takes a full-screen quad texture coordinate and converts it to camera-space position, using the depth from the post-projection depth buffer
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float3 compute_position_camera_space( float2 texcoord )
{
	#if defined(pc) && (DX_VERSION == 9)
		return 1.0f;
	#else  // XENON

		float4 position_texture_space= float4( texcoord, 1.0f, 1.0f );

		// Convert pixel's position from texture space to camera space:
		float4 position_camera_space=      mul( position_texture_space, transpose( texture_to_camera_matrix ));
			   position_camera_space.xyz/= position_camera_space.w;

		float fragment_depth_camera_space= 0.0f;
		#ifdef xenon
		asm
		{
			tfetch2D fragment_depth_camera_space.r___, texcoord, depth_sampler, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled
		};
		#elif DX_VERSION == 11
			fragment_depth_camera_space= sample2D(depth_sampler, texcoord).x;
		#endif

		position_camera_space.xyz= ( position_camera_space.xyz * fragment_depth_camera_space ) / position_camera_space.z;

		return position_camera_space.xyz;
	#endif
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method checks whether the depth sampled at the given occlusion sample point (i.e. the contents of the depth buffer in that screen location)
// is closer or further away than the depth of the occlusion sample point itself. If the depth buffer sample is closer than the occlusion sample depth,
// then there is a surface that is occluding the sample point. In other words, there is another surface that is covering the area in the vicinity of the
// current pixel we're accumulating occlusion information for, and thus there is some amount of occlusion.
//
// If the occluding surface is very close to the pixel being occluded, it will occlude a lot more than when it is further away. And in fact, beyond
// a certain threshold, there needs to be no occlusion at all as we do not want the surfaces far away from the sample we are rendering to occlude it.
// Therefore, we rely on an exponential falloff beyond the 'cutoff_depth_distance' value to fade out occlusion for distant surfaces in the scene.
//
// This method returns the heuristic amount of occlusion.
// If the given sample is occluded by the contents of the depth buffer, returns either 1 (100% occluded) in which case return (1)
// or it isn't occluded (in which case returns 0).
//
// The 'cutoff_depth_distance' value is in post-projection units, determines when we're switching to exponential fall-off for occlusion fade-out.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float compute_occlusion_based_on_depth_delta( float sample_db_depth_delta, float cutoff_depth_distance )
{
	float occlusion;
	//
	// Check if the occlusion sample is in front of the depth buffer sample to determine whether the sample is occluded or not.
	//
	if ( sample_db_depth_delta < 0.0f )
	{
		// Negative depth deltas mean that the occluding surface (from the depth buffer) is behind the sample point, and thus no occlusion occurs:
		occlusion= 0.0f;
	}
	// If the depth delta is positive, the sample is occluded. Next we need to figure out just how much occlusion do we have. Smaller depth deltas
	// should give higher occlusion values (since in that case the occluding surface is closer to the pixel we're computing occlusion for).
	// However, the occlusion falls off to zero with an exponential falloff beyond a depth cutoff threshold.
	//
	else if ( sample_db_depth_delta < cutoff_depth_distance )
	{
		// By default, SSAO algorithm will generate occlusion for objects' silhouettes, creating quasi-halos around the objects.
	    // We attempt to fade those out based on some distance in vertical space. Higher values will fade out more occlusion.
		// In this case, we know that the occluding surface is within a given radius of distance to the occlusion sample
		if ( sample_db_depth_delta > cutoff_depth_distance * ssao_parameters.z )
		{
			// Fully occluded
			occlusion= 1.0f;
		}
		else
		{
			// Not occluded:
			occlusion= 0.0f;
		}
	}
	else
	{
		// Distant objects should not contribute to the occlusion for a given sample ('distant' with respect to the sample itself). This parameter controls
		// how quickly the occlusion contribution for those samples gets faded out. Smaller values means stronger contribution thus creating more possible
		// occlusions in the end
		occlusion= exp2( -sample_db_depth_delta * ssao_parameters.w );
	}

	return occlusion;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Main pixel shader entry point for SSDO computation
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float4 compute_ssao_ps( screen_input_ssao IN ) : SV_Target
{
#if !defined(xenon) && (DX_VERSION == 9)
	return 1.0f;
#else  // XENON

	float2 texcoord= IN.texcoord;

	float3 position_camera_space= compute_position_camera_space( texcoord );

	// Do not compute occlusion on sky and other distant objects:
	if ( position_camera_space.z < cutoff_far_away_distance_depth )
		return 1.0f;

	float3 normal_world_space;
	float4 randomized_offset_vector;

	float  random_offsets_tiling_rate= 8.0f;
	float2 random_offsets_texcoord=    IN.texcoord * random_offsets_tiling_rate;
#ifdef xenon
	asm
	{
		// Sample normals:
		tfetch2D normal_world_space.rgb_,
				 texcoord,
				 normals_sampler,
				 MagFilter= 			point,
				 MinFilter= 			point,
				 MipFilter= 			point,
				 AnisoFilter=			disabled,
				 UseComputedLOD=		0,
				 UseRegisterLOD=		0,
				 LODBias=				0,
				 UseRegisterGradients=	0

		// Sample random vectors around a sphere:
		tfetch2D randomized_offset_vector.rgba,
				 random_offsets_texcoord,
				 random_offsets_sampler,
				 MagFilter= 			point,
				 MinFilter= 			point,
				 MipFilter= 			point,
				 AnisoFilter=			disabled,
				 UseComputedLOD=		0,
				 UseRegisterLOD=		0,
				 LODBias=				0,
				 UseRegisterGradients=	0
	};
#elif DX_VERSION == 11
	normal_world_space= sample2D(normals_sampler, texcoord).rgb;
	randomized_offset_vector= sample2D(random_offsets_sampler, random_offsets_texcoord);
#endif
	// The main normal buffer stores scaled & biased normals (in [0..1] range), bring 'em back to [-1; 1]:
	normal_world_space= normal_world_space * 2.0f - 1.0f;

	// We are computing depth differences for SSAO in camera space since it's more controllable. This means that the normals need to be
	// in camera space so that we can correctly flip the samples to be avove surfaces for sampling occlusion:
	float3 normal_camera_space= mul( float4( normal_world_space, 0 ), transpose( world_to_camera_matrix )).xyz;

	// We would like to maintain a constant radius of influence in screen space. Note that in camera space, negative Z is forward, so negate that first.
	// Screen-space SSAO radius scale should be a per-level parameter which controls how far in screen-space we'll be shooting rays to test for occlusion.
	// This is a scaler, that essentially takes the range for camera-space z into 0..1 range in screen-space, so it should be fairly small. Typical values
	// will be smaller for smaller levels and larger for larger levels.
	//float occlusion_sphere_radius= pow(-position_camera_space.z, 0.333) * ssao_parameters.y;
	float occlusion_sphere_radius= -position_camera_space.z * ssao_parameters.y;

	/* Attempts to get a better function for occlusion_sphere_radius:
	float x= -position_camera_space.z;// * ssao_parameters.y;
	//float occlusion_sphere_radius= x / (1 + x * 0.01);
	float occlusion_sphere_radius= (x + 0.005*x*x) / (1+0.02 * x);
	occlusion_sphere_radius*= ssao_parameters.y;
	*/

	float occlusion= 0.0f;
	float4 random_offset;

	[loop]
	for ( int sample_index=0; sample_index < NUMBER_OF_SSAO_SAMPLES; sample_index++ )
	{
		random_offset= random_offsets[sample_index];

        // Calculate a sample location on a sphere around the world space position to test for occlusion:
		float3 occlusion_sample_position_offset= reflect( random_offset.xyz, randomized_offset_vector.xyz );

		// Check whether the occluder sampler is above or beneath the surface we're sampling. If so, direct this sample to the hemisphere above the surface.
		// This is easily accomplished by checking the sign of the dot product between the normal and the offset vector and if they are more than 90 degrees
		// apart, flipping the offset vector. Note a simple optimization, rather than branching, works, but in some small amount of cases this could produce
		// a zero offset vector. So far that hasn't generated any artifacts.
 		float offset_dot_normal=			dot( occlusion_sample_position_offset, normal_camera_space );
		occlusion_sample_position_offset *= sign( offset_dot_normal );

		// Compute an occlusion sample offset position within the hemisphere above the surface:
		occlusion_sample_position_offset*= random_offset.w * occlusion_sphere_radius;

		float3 occlusion_sample_position_camera_space= occlusion_sample_position_offset + position_camera_space;

		// Project camera space occlusion sample into texture space so that we can sample the depth buffer at that location:
		float4 occlusion_sample_texture_space=		mul( float4( occlusion_sample_position_camera_space, 1.0f ), transpose( camera_to_texture_matrix ));
			   occlusion_sample_texture_space.xyz/= occlusion_sample_texture_space.w;

		// Sample the depth buffer at offsetted sample position to see if there are any surfaces that occlude this sample:
		float depth_buffer_surface_camera_space;
#ifdef xenon
		asm
		{
			tfetch2D depth_buffer_surface_camera_space.r___,
					 occlusion_sample_texture_space.xy,
					 depth_sampler,
					 MagFilter= 	point,
					 MinFilter= 	point,
					 MipFilter= 	point,
					 AnisoFilter=	disabled
		};
#elif DX_VERSION == 11
		depth_buffer_surface_camera_space= sample2D(depth_sampler, occlusion_sample_texture_space.xy).r;
#endif

		// Compute the depth difference between the sample location we are testing and the surface from the depth buffer (in camera space):
		float depth_delta= depth_buffer_surface_camera_space - occlusion_sample_position_camera_space.z;

		// Map the depth delta to occlusion values:
		occlusion+= compute_occlusion_based_on_depth_delta( depth_delta, occlusion_sphere_radius );
	}

    // Average occlusion over the total number of samples:
	occlusion/= number_of_ssao_samples;

	// This parameter controls how dark or faint the contribution of ambient occlusion is to the shadows buffer.
	// Smaller values make SSAO lighter, larger - darker and thus more noticeable.
	occlusion = saturate( occlusion * ssao_parameters.x );

	// Invert the result:
	occlusion= 1.0f - occlusion;

	return occlusion;

#endif // XENON
}

//.............................................................................................................................................................
//.............................................................................................................................................................
//
//															Downsampling the normals buffer
//
//.............................................................................................................................................................
//.............................................................................................................................................................

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
screen_output downsample_normals_vs(vertex_type IN)
{
	screen_output    OUT;
	OUT.texcoord=	 IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;
	return OUT;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float4 downsample_normals_ps( screen_output IN ) : SV_Target
{
#if defined(pc) && (DX_VERSION == 9)
	return 1.0f;
#else
	float3 average_normal_world_space= 0.0f;

	// Perform a box filter on the normals:
	//
	float3 normal_world_space_0, normal_world_space_1, normal_world_space_2, normal_world_space_3;
	float2 texcoord = IN.texcoord;
#ifdef xenon
	asm
	{
		tfetch2D	normal_world_space_0.rgb_,
					texcoord,
					normals_sampler,
					MagFilter= keep,
					MinFilter= keep,
					MipFilter= keep,
					AnisoFilter= disabled,
					OffsetX= -0.5,
					OffsetY= -0.5

		tfetch2D	normal_world_space_1.rgb_,
					texcoord,
					normals_sampler,
					MagFilter= keep,
					MinFilter= keep,
					MipFilter= keep,
					AnisoFilter= disabled,
					OffsetX= -0.5,
					OffsetY= +0.5

		tfetch2D	normal_world_space_2.rgb_,
					texcoord,
					normals_sampler,
					MagFilter= keep,
					MinFilter= keep,
					MipFilter= keep,
					AnisoFilter= disabled,
					OffsetX= +0.5,
					OffsetY= +0.5

		tfetch2D	normal_world_space_3.rgb_,
					texcoord,
					normals_sampler,
					MagFilter= keep,
					MinFilter= keep,
					MipFilter= keep,
					AnisoFilter= disabled,
					OffsetX= +0.5,
					OffsetY= -0.5
	};
#elif DX_VERSION == 11
	normal_world_space_0= normals_sampler.t.Sample(normals_sampler.s, texcoord, int2(0, 0)).rgb;
	normal_world_space_1= normals_sampler.t.Sample(normals_sampler.s, texcoord, int2(0, 1)).rgb;
	normal_world_space_2= normals_sampler.t.Sample(normals_sampler.s, texcoord, int2(1, 1)).rgb;
	normal_world_space_3= normals_sampler.t.Sample(normals_sampler.s, texcoord, int2(1, 0)).rgb;
#endif

	average_normal_world_space=  normal_world_space_0 + normal_world_space_1 + normal_world_space_2 + normal_world_space_3;
	average_normal_world_space/= 4.0f;

	return float4( average_normal_world_space, 0.0f );

#endif
}

//.............................................................................................................................................................
//.............................................................................................................................................................
//
//											Helper methods for depth-aware blurring of the screen-space ambient occlusion
//
//.............................................................................................................................................................
//.............................................................................................................................................................


//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float get_gaussian_distribution_weight( float sigma, int weight_index )
{
	// Compute the support point using the following formula: exp( (3.0f * weight_index / sigma)^2 / 2.0f )
	//
	// Note that for a Gaussian filter of a given variance Sigma, the size of the filter should be 2 * 3 Sigma.
	float x= weight_index / sigma;

	float weight= exp( - x * x * 4.5 );

	return weight;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Get an adjustment amount (weight) for a given quantity, where the weight is between 0 and 1 when the
// quantity is less than threshold and 0 when value is greater than the specified threshold
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float get_delta_difference_weight_less_than_threshold( float value, float value_threshold )
{
	return saturate( 1.0f - value / value_threshold );
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Get an adjustment amount (weight) for a given quantity, where the weight is between 0 and 1 when the
// quantity is greater than threshold and 0 when value is less than the specified threshold
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float get_delta_difference_weight_greater_than_threshold( float value, float value_threshold )
{
	return saturate( 1.0f - value_threshold / value );
}

/// Select one of these defines to enable different sizes for blur kernels for SSAO blurring:
//#define SSAO_BLUR_KERNEL_RADIUS 3	// Corresponds to a 7-tap filter
//#define SSAO_BLUR_KERNEL_RADIUS 4	// Corresponds to a 9-tap filter
#define SSAO_BLUR_KERNEL_RADIUS 5	// Corresponds to an 11-tap filter

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method is designed to filter the SSAO results using depth- and normal-aware Gaussian filter (quasi-bilateral).
// The goals is to preserve depth and normal discontinuity across SSAO results. Thisï¿½blurï¿½kernel samplesï¿½theï¿½nearbyï¿½pixelsï¿½asï¿½aï¿½regularï¿½Gaussianï¿½blurï¿½
// shaderï¿½would,ï¿½yetï¿½theï¿½normalï¿½andï¿½depthï¿½forï¿½eachï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½sampledï¿½asï¿½well.ï¿½Ifï¿½eitherï¿½theï¿½
// depthï¿½fromï¿½Gaussianï¿½sampleï¿½differsï¿½fromï¿½theï¿½centerï¿½tapï¿½byï¿½moreï¿½thanï¿½aï¿½certainï¿½threshold,ï¿½orï¿½theï¿½dotï¿½productï¿½ofï¿½theï¿½Gaussianï¿½sampleï¿½andï¿½theï¿½centerï¿½
// tapï¿½normalï¿½isï¿½lessï¿½thanï¿½aï¿½certainï¿½thresholdï¿½value,ï¿½thenï¿½theï¿½Gaussianï¿½weightï¿½isï¿½reducedï¿½toï¿½zero.ï¿½Theï¿½sumï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½thenï¿½
// renormalizedï¿½toï¿½accountï¿½forï¿½theï¿½missingï¿½samples.ï¿½
// This particular method is designed for a Gaussian filter which radius can be easily changed by a #define above.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float filter_ssao_with_normals( float2 offset_direction, float2 texcoord )
{
	// Sample depth buffer for the center tap
	float center_tap_depth_camera_space= sample2Dlod( depth_sampler, texcoord, 0).r;

	// Sample center tap normal:
	float3  center_tap_normal= sample2Dlod( normals_sampler, texcoord, 0).rgb * 2.0f - 1.0f;

	float  sample_occlusion= 0.0f;
	float  sample_depth=	 0.0f;
	float3 sample_normal=	 0.0f;

	float  weighted_occlusion_sum=	0.0f;
	float  total_weight=			0.0f;

	const float filter_radius= SSAO_BLUR_KERNEL_RADIUS;

    const int number_of_taps= filter_radius * 2 + 1;		// Optimization: use constant filter size + precomputed weights and filter offsets
	float4 sample_texcoord= 0.0f;

	[loop]
    for ( int sample_index= 0; sample_index < number_of_taps; sample_index++ )
    {
		float location_delta= sample_index - filter_radius;  // Distance from center of filter
		sample_texcoord.xy=   texcoord + location_delta * offset_direction * pixel_size;

		float sample_depth_camera_space= sample2Dlod( depth_sampler, sample_texcoord.xy, 0).r;

		float sample_weight = get_gaussian_distribution_weight( filter_radius, location_delta );
		float depth_delta= abs( center_tap_depth_camera_space - sample_depth_camera_space );

		sample_normal= sample2Dlod( normals_sampler, sample_texcoord.xy, 0).rgb * 2.0f - 1.0f;
		float normals_cosine= dot( sample_normal, center_tap_normal );

		// If this sample's depth is farther than threshold value from the center sample depth or the normal points further away than the
		// specified threshold, don't let this sample contribute to the filtered result:
		float depth_delta_weight= get_delta_difference_weight_less_than_threshold( depth_delta,
																				   ssao_filter_parameters.x );		// ssao_filter_parameters.x = depth_delta_threshold

		sample_weight*= depth_delta_weight;

		float normals_delta_weight= get_delta_difference_weight_greater_than_threshold( normals_cosine,
																					    ssao_filter_parameters.y ); // ssao_filter_parameters.y = normals_delta_threshold

		sample_weight*= normals_delta_weight;

		sample_occlusion= sample2Dlod( ssao_sampler, sample_texcoord.xy, 0).r;

		weighted_occlusion_sum+= sample_weight * sample_occlusion;
		total_weight+=			 sample_weight;
    }

	return weighted_occlusion_sum / total_weight;

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method is designed to filter the SSAO results using only depth-aware Gaussian filter (quasi-bilateral).
// The goals is to preserve depth discontinuity across SSAO results. Thisï¿½blurï¿½kernel samplesï¿½theï¿½nearbyï¿½pixelsï¿½asï¿½aï¿½regularï¿½Gaussianï¿½blurï¿½
// shaderï¿½would,ï¿½yetï¿½depthï¿½forï¿½eachï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½sampledï¿½asï¿½well.ï¿½Ifï¿½theï¿½depthï¿½fromï¿½Gaussianï¿½sampleï¿½differsï¿½fromï¿½theï¿½centerï¿½
// tapï¿½byï¿½moreï¿½thanï¿½aï¿½certainï¿½threshold, thenï¿½theï¿½Gaussianï¿½weightï¿½isï¿½reducedï¿½toï¿½zero.ï¿½Theï¿½sumï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½thenï¿½renormalizedï¿½toï¿½accountï¿½forï¿½
// theï¿½missingï¿½samples.ï¿½
// This particular method is designed for a separable Gaussian filter which radius can be easily changed by a #define above.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float filter_ssao_dynamic_kernel( float2 offset_direction, float2 texcoord )
{
	// Sample depth buffer for the center tap
	float center_tap_depth_camera_space= sample2Dlod( depth_sampler, texcoord, 0 ).r;

	float  sample_occlusion= 0.0f;
	float  sample_depth=	 0.0f;

	float  weighted_occlusion_sum=	0.0f;
	float  total_weight=			0.0f;

	const float filter_radius= SSAO_BLUR_KERNEL_RADIUS;

    const int number_of_taps= filter_radius * 2 + 1;		// Optimization: use constant filter size + precomputed weights and filter offsets
	float4 sample_texcoord= 0.0f;

	[loop]
    for ( int sample_index= 0; sample_index < number_of_taps; sample_index++ )
    {
		float location_delta= sample_index - filter_radius;  // Distance from center of filter
		sample_texcoord.xy=   texcoord + location_delta * offset_direction * pixel_size;

		float sample_depth_camera_space= sample2Dlod( depth_sampler, sample_texcoord.xy, 0 ).r;

		float fSampleWeight = get_gaussian_distribution_weight( filter_radius, location_delta );
		float depth_delta= abs( center_tap_depth_camera_space - sample_depth_camera_space );

		// If this sample's depth is farther than threshold value from the center sample depth or the normal points further away than the
		// specified threshold, don't let this sample contribute to the filtered result:
		float depth_delta_weight= get_delta_difference_weight_less_than_threshold( depth_delta,
																				   ssao_filter_parameters.x );		// ssao_filter_parameters.x = depth_delta_threshold

		fSampleWeight*= depth_delta_weight;

		sample_occlusion= sample2Dlod( ssao_sampler, sample_texcoord.xy, 0 ).r;

		weighted_occlusion_sum+= fSampleWeight * sample_occlusion;
		total_weight+=			 fSampleWeight;
    }

	return weighted_occlusion_sum / total_weight;

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method is designed to filter the SSAO results using only depth-aware Gaussian filter (quasi-bilateral).
// The goals is to preserve depth discontinuity across SSAO results. Thisï¿½blurï¿½kernel samplesï¿½theï¿½nearbyï¿½pixelsï¿½asï¿½aï¿½regularï¿½Gaussianï¿½blurï¿½
// shaderï¿½would,ï¿½yetï¿½depthï¿½forï¿½eachï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½sampledï¿½asï¿½well.ï¿½Ifï¿½theï¿½depthï¿½fromï¿½Gaussianï¿½sampleï¿½differsï¿½fromï¿½theï¿½centerï¿½
// tapï¿½byï¿½moreï¿½thanï¿½aï¿½certainï¿½threshold, thenï¿½theï¿½Gaussianï¿½weightï¿½isï¿½reducedï¿½toï¿½zero.ï¿½Theï¿½sumï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½thenï¿½renormalizedï¿½toï¿½accountï¿½forï¿½
// theï¿½missingï¿½samples.ï¿½
// This method is coded very specifically for an 11-tap separable horizontal Gaussian for performance reasons.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float filter_ssao_horizontal_11_tap_bilateral_gaussian( float2 texcoord )
{
	// Sample depth buffer for the center tap
	float center_tap_depth_camera_space= sample2Dlod( depth_sampler, texcoord, 0 ).r;

	float  sample_occlusion= 0.0f;
	float  sample_depth=	 0.0f;

	float  weighted_occlusion_sum=	0.0f;
	float  total_weight=			0.0f;
	float4 sample_texcoord=			0.0f;
	float  sample_weight=			0.0f;

	const float2 offsets[11] = { { -5, 0 }, { -4, 0 }, { -3, 0 }, { -2, 0 }, { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 4, 0 }, { 5, 0 } };
	const float  weights[11] = { 0.0111089965, 0.0561347628, 0.197898699, 0.486752256, 0.835270211, 1, 0.835270211, 0.486752256, 0.197898699, 0.0561347628,0.0111089965  };

	for ( int sample_index= 0; sample_index < 11; sample_index++ )
    {
		sample_texcoord.xy= texcoord + offsets[sample_index] * pixel_size;

		float sample_depth_camera_space= sample2Dlod( depth_sampler, sample_texcoord.xy, 0 ).r;

		float depth_delta=		  abs( center_tap_depth_camera_space - sample_depth_camera_space );
		float depth_delta_weight= get_delta_difference_weight_less_than_threshold( depth_delta, ssao_filter_parameters.x );

		sample_weight= weights[sample_index] * depth_delta_weight;

		sample_occlusion= sample2Dlod( ssao_sampler, sample_texcoord.xy, 0 ).r;

		weighted_occlusion_sum+= sample_weight * sample_occlusion;
		total_weight+=			 sample_weight;
    }

	return weighted_occlusion_sum / total_weight;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// This method is designed to filter the SSAO results using only depth-aware Gaussian filter (quasi-bilateral).
// The goals is to preserve depth discontinuity across SSAO results. Thisï¿½blurï¿½kernel samplesï¿½theï¿½nearbyï¿½pixelsï¿½asï¿½aï¿½regularï¿½Gaussianï¿½blurï¿½
// shaderï¿½would,ï¿½yetï¿½depthï¿½forï¿½eachï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½sampledï¿½asï¿½well.ï¿½Ifï¿½theï¿½depthï¿½fromï¿½Gaussianï¿½sampleï¿½differsï¿½fromï¿½theï¿½centerï¿½
// tapï¿½byï¿½moreï¿½thanï¿½aï¿½certainï¿½threshold, thenï¿½theï¿½Gaussianï¿½weightï¿½isï¿½reducedï¿½toï¿½zero.ï¿½Theï¿½sumï¿½ofï¿½theï¿½Gaussianï¿½samplesï¿½isï¿½thenï¿½renormalizedï¿½toï¿½accountï¿½forï¿½
// theï¿½missingï¿½samples.ï¿½
// This method is coded very specifically for an 11-tap separable horizontal Gaussian for performance reasons.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float filter_ssao_vertical_11_tap_bilateral_gaussian( float2 texcoord )
{
	// Sample depth buffer for the center tap
	float center_tap_depth_camera_space= sample2Dlod( depth_sampler, texcoord, 0 ).r;

	float  sample_occlusion= 0.0f;
	float  sample_depth=	 0.0f;

	float  weighted_occlusion_sum=	0.0f;
	float  total_weight=			0.0f;
	float4 sample_texcoord=			0.0f;
	float  sample_weight=			0.0f;

	const float2 offsets[11]= { { 0, -5 }, { 0, -4 }, { 0, -3 }, { 0, -2 }, { 0, -1 }, { 0, 0 }, { 0, 1 }, { 0, 2 }, { 0, 3 }, { 0, 4 }, { 0, 5 } };
	const float  weights[11]= { 0.0111089965, 0.0561347628, 0.197898699, 0.486752256, 0.835270211, 1, 0.835270211, 0.486752256, 0.197898699, 0.0561347628,0.0111089965  };

	for ( int sample_index= 0; sample_index < 11; sample_index++ )
    {
		sample_texcoord.xy= texcoord + offsets[sample_index] * pixel_size;

		float sample_depth_camera_space= sample2Dlod( depth_sampler, sample_texcoord.xy, 0 ).r;

		float depth_delta=		  abs( center_tap_depth_camera_space - sample_depth_camera_space );
		float depth_delta_weight= get_delta_difference_weight_less_than_threshold( depth_delta, ssao_filter_parameters.x );

		sample_weight =   weights[sample_index] * depth_delta_weight;
		sample_occlusion= sample2Dlod( ssao_sampler, sample_texcoord.xy, 0 ).r;

		weighted_occlusion_sum+= sample_weight * sample_occlusion;
		total_weight+=			 sample_weight;
    }

	return weighted_occlusion_sum / total_weight;
}

//.............................................................................................................................................................
//.............................................................................................................................................................
//
//											Horizontal depth-aware blurring of the screen-space ambient occlusion
//
//.............................................................................................................................................................
//.............................................................................................................................................................

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
screen_output compute_ssao_horizontal_blur_vs( vertex_type IN )
{
	screen_output    OUT;
	OUT.texcoord=	 IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;
	return OUT;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Main pixel shader entry point for SSDO horizontal blur pass
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float4 compute_ssao_horizontal_blur_ps( screen_input IN ) : SV_Target
{
    float2 offset_direction= float2( 1.0f, 0.0f ); // horizontal blur

	//return filter_ssao_dynamic_kernel( offset_direction, IN.texcoord );
	//return filter_ssao_with_normals( offset_direction, IN.texcoord );
	return filter_ssao_horizontal_11_tap_bilateral_gaussian( IN.texcoord );
}

//.............................................................................................................................................................
//.............................................................................................................................................................
//
//											Vertical depth-aware blurring of the screen-space ambient occlusion
//
//.............................................................................................................................................................
//.............................................................................................................................................................

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
screen_output compute_ssao_vertical_blur_vs( vertex_type IN )
{
	screen_output    OUT;
	OUT.texcoord=	 IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;
	return OUT;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Main pixel shader entry point for SSDO vertical blur pass
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float4 compute_ssao_vertical_blur_ps( screen_input IN ) : SV_Target
{
    float2 offset_direction= float2( 0.0f, 1.0f ); // vertical blur

	//return filter_ssao_dynamic_kernel( offset_direction, IN.texcoord );
	//return filter_ssao_with_normals( offset_direction, IN.texcoord );
	return filter_ssao_vertical_11_tap_bilateral_gaussian( IN.texcoord );
}


//.............................................................................................................................................................
//.............................................................................................................................................................
//
//											Depth-aware upsample and apply SSAO to the main shadow mask
//
//.............................................................................................................................................................
//.............................................................................................................................................................

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
screen_output upsample_ssao_and_apply_vs( vertex_type IN )
{
	screen_output    OUT;
	OUT.texcoord=	 IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;
	return OUT;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Main pixel shader entry point for depth-aware upsample and apply SSAO pass
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float4 upsample_ssao_and_apply_ps( screen_input IN ) : SV_Target
{
#ifndef UPSAMPLE_SSAO_HIGH_QUALITY
	return sample2D( ssao_sampler, IN.texcoord ).rrrr;
#else

	#if !defined(xenon) && (DX_VERSION == 9)
		return 1.0f;
	#else
		float4 low_res_depths;
		float  high_res_depth;
		float4 ssao_values;

		float2 texcoord= IN.texcoord;

		#ifdef xenon
		asm
		{
			tfetch2D low_res_depths.x___,
					 texcoord,
					 depth_low_res_sampler,
					 OffsetX = -0.5,
					 OffsetY = -0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D low_res_depths._x__,
					 texcoord,
					 depth_low_res_sampler,
					 OffsetX = -0.5,
					 OffsetY = +0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D low_res_depths.__x_,
					 texcoord,
					 depth_low_res_sampler,
					 OffsetX = +0.5,
					 OffsetY = -0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D low_res_depths.___x,
					 texcoord,
					 depth_low_res_sampler,
					 OffsetX = +0.5,
					 OffsetY = +0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D high_res_depth.x___,
					 texcoord,
					 depth_sampler,
					 OffsetX = +0.0,
					 OffsetY = +0.0,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D ssao_values.x___,
					 texcoord,
					 ssao_sampler,
					 OffsetX = -0.5,
					 OffsetY = -0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D ssao_values._x__,
					 texcoord,
					 ssao_sampler,
					 OffsetX = -0.5,
					 OffsetY = +0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D ssao_values.__x_,
					 texcoord,
					 ssao_sampler,
					 OffsetX = +0.5,
					 OffsetY = -0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0

			tfetch2D ssao_values.___x,
					 texcoord,
					 ssao_sampler,
					 OffsetX = +0.5,
					 OffsetY = +0.5,
					 MagFilter= 			point,
					 MinFilter= 			point,
					 MipFilter= 			point,
					 AnisoFilter=			disabled,
					 UseComputedLOD=		0,
					 UseRegisterLOD=		0,
					 LODBias=				0,
					 UseRegisterGradients=	0
		};
		#elif DX_VERSION == 11
			low_res_depths.x= depth_low_res_sampler.t.Sample(depth_low_res_sampler.s, texcoord, int2(0, 0)).r;
			low_res_depths.y= depth_low_res_sampler.t.Sample(depth_low_res_sampler.s, texcoord, int2(0, 1)).r;
			low_res_depths.z= depth_low_res_sampler.t.Sample(depth_low_res_sampler.s, texcoord, int2(1, 0)).r;
			low_res_depths.w= depth_low_res_sampler.t.Sample(depth_low_res_sampler.s, texcoord, int2(1, 1)).r;
			ssao_values.x= depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(0, 0)).r;
			ssao_values.y= depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(0, 1)).r;
			ssao_values.z= depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(1, 0)).r;
			ssao_values.w= depth_sampler.t.Sample(depth_sampler.s, texcoord, int2(1, 1)).r;
		#endif

		float fall_off_constant= 10.0;

		// Convert the high res depth from post-projection to camera space in order to do correct comparison with low res depth, which is now in camera space
		float4 high_res_depth_camera_space=      mul( float4( texcoord, high_res_depth, 1.0f ), transpose( texture_to_camera_matrix ));
		high_res_depth_camera_space.xyz/= high_res_depth_camera_space.w;

		float  depth_delta= low_res_depths - high_res_depth_camera_space.z;
		float  exponent=    -fall_off_constant * depth_delta;

		float4 weight= min(  exp2( exponent ), float4( FLT_MAX, FLT_MAX, FLT_MAX, FLT_MAX) );
		float upsampled_ssao_result= dot( ssao_values, weight ) / dot( weight, float4( 1.0f, 1.0f, 1.0f, 1.0f ));

		return upsampled_ssao_result;

	#endif
#endif
}