/* ---------------------------------------------------

	Common patchy effect function between full screen
	patchy fog and planar fog.
	for planar fog, we define marco:
		PATCHY_EFFECT_ON_PLANAR_FOG		

--------------------------------------------------- */


#ifdef PATCHY_EFFECT_ON_PLANAR_FOG
	#define _patchy_layer_depth						attenuation_data.x
	#define _patchy_layer_one_over_thickness		attenuation_data.y
#endif //PATCHY_EFFECT_ON_PLANAR_FOG

void evaluate_patchy_effect(
    in float2 screen_normalized_biased,
	in float view_space_scene_depth,
	in float3 pixel_in_world_space,
	
	in float4 texcoord_basis,
	in float4 attenuation_data,
	in float4 eye_position,	
	in float4 sheet_fade_factors0,
	in float4 sheet_fade_factors1,
	in float4 sheet_depths0,
	in float4 sheet_depths1,
	in float4 tex_coord_transform0,
	in float4 tex_coord_transform1,
	in float4 tex_coord_transform2,
	in float4 tex_coord_transform3,
	in float4 tex_coord_transform4,
	in float4 tex_coord_transform5,
	in float4 tex_coord_transform6,
	in float4 tex_coord_transform7,
	in texture_sampler_2d tex_noise,

#ifdef PATCHY_EFFECT_ON_PLANAR_FOG
	in float4 planar_fog_plane_coeffs,
#endif //PATCHY_EFFECT_ON_PLANAR_FOG

	out float inscatter,
	out float optical_depth)
{	
	// This value is positive whenever a sheet is visible (e.g. in front of the existing scene)
	// and negative when a sheet is further away than the current scene point.
	float4 view_space_depth_diff0= view_space_scene_depth - sheet_depths0.xyzw;
	float4 view_space_depth_diff1= view_space_scene_depth - sheet_depths1.xyzw;
	
	float4 fade_factor0= 1.0f;
	float4 fade_factor1= 1.0f;
	
	// The depth fade factor approaches 1.0 the further in front a sheet is from the scene depth.
	// Lower values of attenuation_data.z ("Depth-fade factor" in the tag) cause more gradual fading, while larger values cause sharper boundaries.
	// Clamp the fade factor below 1 so that the sheet doesn't get magnified the further away it is from the scene depth.
	// Clamp it above 0 so that sheets behind the scene don't contribute negatively.
	float4 depth_fade_factor;
	depth_fade_factor= saturate(1.0f - exp(-view_space_depth_diff0.xyzw * attenuation_data.z));
	fade_factor0*= depth_fade_factor;		// max(float4(0.0f, 0.0f, 0.0f, 0.0f), min(float4(1.0f, 1.0f, 1.0f, 1.0f), depth_fade_factor));	
	depth_fade_factor= saturate(1.0f - exp(-view_space_depth_diff1.xyzw * attenuation_data.z));
	fade_factor1*= depth_fade_factor;		// max(float4(0.0f, 0.0f, 0.0f, 0.0f), min(float4(1.0f, 1.0f, 1.0f, 1.0f), depth_fade_factor));
	
	// Each sheet has an additional independent fade factor which is the product of: 
	// 1) the first and last sheets' need to be faded-in/faded-out to avoid popping
	// 2) the density multiplier applied to every sheet, controlled by the artist ("Sheet density" in the tag)
	fade_factor0*= sheet_fade_factors0;
	fade_factor1*= sheet_fade_factors1;

	
	// Sample 8 sheets worth of data using 8 different texture coordinate sets
	float2 noise_uv;
	float4 noise_values0, noise_values1;	
	{
		// tex_coord_transform.xy gives us the texture coordinate at the center of the screen
		// tex_coord_transform.zw gives us the [u,v] texture coordinate half-extents for the screen
		// texcoord_basis.xy gives us the rotated u basis vector, texcoord_basis.zw gives us the rotated v basis vector	

		texcoord_basis.xy*= screen_normalized_biased.x;
		texcoord_basis.zw*= screen_normalized_biased.y;

		noise_uv= tex_coord_transform0.xy 
			+ tex_coord_transform0.z * texcoord_basis.xy
			+ tex_coord_transform0.w * texcoord_basis.zw;
		noise_values0.x= sample2D(tex_noise, noise_uv).x;

		noise_uv= tex_coord_transform1.xy 
			+ tex_coord_transform1.z * texcoord_basis.xy
			+ tex_coord_transform1.w * texcoord_basis.zw;
		noise_values0.y= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform2.xy 
			+ tex_coord_transform2.z * texcoord_basis.xy
			+ tex_coord_transform2.w * texcoord_basis.zw;
		noise_values0.z= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform3.xy 
			+ tex_coord_transform3.z * texcoord_basis.xy
			+ tex_coord_transform3.w * texcoord_basis.zw;
		noise_values0.w= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform4.xy 
			+ tex_coord_transform4.z * texcoord_basis.xy
			+ tex_coord_transform4.w * texcoord_basis.zw;
		noise_values1.x= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform5.xy 
			+ tex_coord_transform5.z * texcoord_basis.xy
			+ tex_coord_transform5.w * texcoord_basis.zw;
		noise_values1.y= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform6.xy 
			+ tex_coord_transform6.z * texcoord_basis.xy
			+ tex_coord_transform6.w * texcoord_basis.zw;
		noise_values1.z= sample2D(tex_noise, noise_uv).x;
		
		noise_uv= tex_coord_transform7.xy 
			+ tex_coord_transform7.z * texcoord_basis.xy
			+ tex_coord_transform7.w * texcoord_basis.zw;
		noise_values1.w= sample2D(tex_noise, noise_uv).x;		
	}


	#ifdef PATCHY_EFFECT_ON_PLANAR_FOG
		
		float eye_depth_in_fog= dot(planar_fog_plane_coeffs, float4(eye_position.xyz, 1.0f));

		float3 view_vector= normalize(pixel_in_world_space - eye_position);
		float depth_change_in_fog= dot(planar_fog_plane_coeffs.xyz, view_vector);
		
		float4 height0= depth_change_in_fog * sheet_depths0.xyzw + eye_depth_in_fog;
		float4 height_fade_factor0= 
			saturate(_patchy_layer_one_over_thickness * (height0 - _patchy_layer_depth));
		fade_factor0*= height_fade_factor0;	

		float4 height1= depth_change_in_fog * sheet_depths1.xyzw + eye_depth_in_fog;				
		float4 height_fade_factor1= 
			saturate(_patchy_layer_one_over_thickness * (height1 - _patchy_layer_depth));
		fade_factor1*= height_fade_factor1;

	#else	
		// Height-fading
		//
		// Since the post-effect is rendered with a view-space depth of 1.0, we can take the view vector (eye -> sheet)
		// and scale it by the sheet depth to get the vector from the eye to each particular sheet.
		// However, we only need the world-space height coordinate (z) so we can do this with scalar math on 4 sheets at once.
		// We exponentially fade fog so that it decays above a certain height ("Full intensity height" in the tag).
		float3 view_vector= normalize(pixel_in_world_space - eye_position);

		float4 height0= view_vector.zzzz * sheet_depths0.xyzw + eye_position.zzzz;
		float4 height_fade_factor0= saturate(exp(attenuation_data.yyyy * (attenuation_data.xxxx - height0.xyzw)));
		fade_factor0*= height_fade_factor0;	

		float4 height1= view_vector.zzzz * sheet_depths1.xyzw + eye_position.zzzz;
		float4 height_fade_factor1= saturate(exp(attenuation_data.yyyy * (attenuation_data.xxxx - height1.xyzw)));
		fade_factor1*= height_fade_factor1;

	#endif //PATCHY_EFFECT_ON_PLANAR_FOG
	
	// The line integral of fog is simply the sum of the products of fade factors and noise values
	optical_depth= dot(fade_factor0, noise_values0) + dot(fade_factor1, noise_values1);	


	// View-dependent scattering calculations	
	inscatter= 1.0f-exp2(-optical_depth);	
}

