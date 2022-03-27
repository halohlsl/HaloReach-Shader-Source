//#line 2 "source\rasterizer\hlsl\shadow_generate.fx"


#if defined(entry_point_dynamic_light) || defined (entry_point_dynamic_light_cinematic)
	sampler	shadow_depth_map_1	: register(s5);
#else
	#ifndef shadow_depth_map_1
		sampler shadow_depth_map_1;
	#endif
#endif // dynamic_light

#ifndef NO_SHADOW_GENERATE_PASS

#ifdef alpha_test
#if ALPHA_TEST(alpha_test)!=ALPHA_TEST_off
#define SHADOW_GENERATE_USES_TEXCOORD
#endif //
#endif // alpha_test

#ifdef SAMPLE_ALBEDO_FOR_SHADOW_GENERATE
#undef SHADOW_GENERATE_USES_TEXCOORD
#define SHADOW_GENERATE_USES_TEXCOORD
#endif // SAMPLE_ALBEDO_FOR_SHADOW_GENERATE

void shadow_generate_vs(	
	in vertex_type vertex,
	out float4 screen_position : POSITION
#ifdef pc	
	, out float4 screen_position_copy : TEXCOORD0
#endif // pc
#ifdef SHADOW_GENERATE_USES_TEXCOORD
	, out float2 texcoord : TEXCOORD1
#endif // SHADOW_GENERATE_USES_TEXCOORD
	)
{
	float4 local_to_world_transform[3];
	float3 binormal;
	
	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, screen_position, binormal);

#ifdef pc
	screen_position_copy= screen_position;	
#endif // pc

#ifdef SHADOW_GENERATE_USES_TEXCOORD
   	texcoord= vertex.texcoord;
#endif // SHADOW_GENERATE_USES_TEXCOORD
} // shadow_generate_vs


float4 shadow_generate_ps(
#ifdef pc
	in float4 screen_position : TEXCOORD0
#ifdef SHADOW_GENERATE_USES_TEXCOORD
	, in float2 texcoord : TEXCOORD1
#endif // SHADOW_GENERATE_USES_TEXCOORD
#else // xenon
#ifdef SHADOW_GENERATE_USES_TEXCOORD
	in float2 texcoord : TEXCOORD1
#endif // SHADOW_GENERATE_USES_TEXCOORD
#endif // xenon
	) : COLOR
{
#ifdef SAMPLE_ALBEDO_FOR_SHADOW_GENERATE
	float4 albedo;
	float3 normal;
	calc_albedo_ps(texcoord, albedo, normal);
	calc_alpha_test_ps(texcoord, albedo);
#else
#ifndef SHADOW_GENERATE_USES_TEXCOORD
	float2 texcoord= 0.0f;
#endif // #SHADOW_GENERATE_USES_TEXCOORD
	calc_alpha_test_ps(texcoord);
#endif

	float alpha= 1.0f;
#ifndef NO_ALPHA_TO_COVERAGE
//	alpha= output_alpha;
#endif

#ifdef pc
	float buffer_depth= screen_position.z / screen_position.w;
	return float4(buffer_depth, buffer_depth, buffer_depth, alpha);
#else // xenon
	return float4(1.0f, 1.0f, 1.0f, alpha);
#endif // xenon
}

#endif // NO_SHADOW_GENERATE_PASS


#define PCF_WIDTH 4
#define PCF_HEIGHT 4

#ifdef pc
const float2 pixel_size= float2(1.0/512.0f, 1.0/512.0f);		// ###ctchou $TODO THIS NEEDS TO BE PASSED IN!!!
#endif

#include "shared\texture.fx"


float sample_percentage_closer(float3 fragment_shadow_position, float depth_bias)
{
	float color= step(fragment_shadow_position.z, tex2D_offset_point(shadow_depth_map_1, fragment_shadow_position.xy, 0.0f, 0.0f).r);
	return color;
}


float sample_percentage_closer_PCF_3x3_block(float3 fragment_shadow_position, float depth_bias)					// 9 samples, 0 predicated
{
	float2 texel= fragment_shadow_position.xy;
	float4 blend= 1.0f;
	
	float4 max_depth= depth_bias;											// x= [0,0],    y=[-1/1,0] or [0,-1/1],     z=[-1/1,-1/1],		w=[-2/2,0] or [0,-2/2]
	max_depth *= float4(-1.0f, -sqrt(20.0f), -3.0f, -sqrt(26.0f));			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;
	
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, -1.0f).r) + 
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, -1.0f).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, -1.0f).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +0.0f).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +0.0f).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +0.0f).r) +
					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +1.0f).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +1.0f).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +1.0f).r);
					
	return color / 9.0f;
}


float sample_percentage_closer_PCF_3x3_block_predicated(float3 fragment_shadow_position, float depth_bias)					// 9 samples, 5 predicated on 4
{
	float2 texel= fragment_shadow_position.xy;
	float4 blend= 1.0f;
	
	float4 max_depth= depth_bias;											// x= [0,0],    y=[-1/1,0] or [0,-1/1],     z=[-1/1,-1/1],		w=[-2/2,0] or [0,-2/2]
	max_depth *= float4(-1.0f, -sqrt(20.0f), -3.0f, -sqrt(26.0f));			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	float color=	
				step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, -1.0f).r) + 
				step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, -1.0f).r) +
				step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +1.0f).r) +
				step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +1.0f).r);
	
	if ((color > 0.1f) && (color < 3.9f))
	{
		color +=	step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, -1.0f).r) +
					step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +0.0f).r) +
					step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +0.0f).r) +
					step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +0.0f).r) +
					step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +1.0f).r);
		return color / 9.0f;
	}
	else
	{
		return color / 4.0f;
	}
}


float sample_percentage_closer_PCF_3x3_diamond_predicated(float3 fragment_shadow_position, float depth_bias)		// 13 samples, 9 predicated on 4
{
	float2 texel= fragment_shadow_position.xy;

	float4 max_depth= depth_bias;											// x= [0,0],    y=[-1/1,0] or [0,-1/1],     z=[-1/1,-1/1],		w=[-2/2,0] or [0,-2/2]
	max_depth *= float4(-1.0f, -sqrt(20.0f), -3.0f, -sqrt(26.0f));			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	float color= 
			step(max_depth.w, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, -2.0f).r) +
			step(max_depth.w, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +2.0f).r) +
			step(max_depth.w, tex2D_offset_point(shadow_depth_map_1, texel, -2.0f, +0.0f).r) +
			step(max_depth.w, tex2D_offset_point(shadow_depth_map_1, texel, +2.0f, +0.0f).r);
			
	if ((color > 0.1f) && (color < 3.9f))
	{
		float4 blend= 1.0f;
		color	+=		blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, -1.0f).r) + 
						1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, -1.0f).r) +
						blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, -1.0f).r) +
						blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +0.0f).r) +
						1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +0.0f).r) +
						blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +0.0f).r) +
						blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, -1.0f, +1.0f).r) +
						1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel, +0.0f, +1.0f).r) +
						blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel, +1.0f, +1.0f).r);
		
		return color / 13.0f;
	}
	else
	{
		return color / 4.0f;
	}
}


float sample_percentage_closer_PCF_5x5_block_predicated(float3 fragment_shadow_position, float depth_bias)
{
	float2 texel1= fragment_shadow_position.xy;

	float4 blend;
#ifdef pc
	fragment_shadow_position.xy= (fragment_shadow_position.xy * 480.0f);
	blend.xy= fragment_shadow_position.xy - floor(fragment_shadow_position.xy);			// bilinear-sampled filter
#else
#ifndef VERTEX_SHADER
//	fragment_shadow_position.xy += 0.5f;
	asm {
		getWeights2D blend.xy, fragment_shadow_position.xy, shadow_depth_map_1, MagFilter=linear, MinFilter=linear
	};
#endif
#endif
	blend.zw= 1.0f - blend.xy;

#define offset_0 -1.5f
#define offset_1 -0.5f
#define offset_2 +0.5f
#define offset_3 +1.5f

	float3 max_depth= depth_bias;							// x= central samples,   y = adjacent sample,   z= diagonal sample
	max_depth *= float3(-2.0f, -sqrt(5.0f), -4.0f);			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;

	// 4x4 point and 3x3 bilinear
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_0).r) + 
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_0).r) +
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_0).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_0).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_1).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_1).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_1).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_2).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_2).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_2).r) +
					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_0, offset_3).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_1, offset_3).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow_depth_map_1, texel1, offset_2, offset_3).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow_depth_map_1, texel1, offset_3, offset_3).r);
					
	color /= 9.0f;

	return color;
}


// #define DEBUG_CLIP

void shadow_apply_vs(
	in vertex_type vertex,
	out float4 screen_position : POSITION
/*	out float3 world_position : TEXCOORD0,
	out float2 texcoord : TEXCOORD1,
//	out float4 bump_texcoord : TEXCOORD2,		// UNUSED
	out float3 normal : TEXCOORD3,
	out float3 fragment_shadow_position : TEXCOORD4,
	out float3 extinction : COLOR0,
	out float3 inscatter : COLOR1
*/	)
{
	float4 local_to_world_transform[3];
	float3 binormal;
	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, screen_position, binormal);
/*
	world_position= vertex.position;
	// project vertex
   	texcoord= vertex.texcoord;
	normal= vertex.normal;
	
	compute_scattering(Camera_Position, vertex.position, extinction, inscatter);
	
	fragment_shadow_position.x= dot(float4(world_position, 1.0), Shadow_Projection[0]);
	fragment_shadow_position.y= dot(float4(world_position, 1.0), Shadow_Projection[1]);
	fragment_shadow_position.z= dot(float4(world_position, 1.0), Shadow_Projection[2]);
*/
}

accum_pixel shadow_apply_ps(
/*	in float3 world_position : TEXCOORD0,
	in float2 texcoord : TEXCOORD1,
//	in float4 bump_texcoord : TEXCOORD2,
	in float3 normal : TEXCOORD3,
	in float3 fragment_shadow_position : TEXCOORD4,
	in float3 extinction : COLOR0,
	in float3 inscatter : COLOR1
*/	)
{
/*
	calc_alpha_test_ps(texcoord);

	// transform position by shadow projection
//	float3 fragment_shadow_position; // = transform_point(world_position, shadow_projection_1);
//	fragment_shadow_position.x= dot(float4(world_position, 1.0), p_vmf_lighting_constant_0);			// ###ctchou $TODO $PERF pass float4(world_position, 1.0) from vertex shader
//	fragment_shadow_position.y= dot(float4(world_position, 1.0), p_vmf_lighting_constant_1);			// ###ctchou $TODO $PERF or even better - do this transformation in the vertex shader
//	fragment_shadow_position.z= dot(float4(world_position, 1.0), p_vmf_lighting_constant_2);			// ###ctchou $TODO $PERF and pass the transformed point to the pixel shader

	// compute maximum slope given normal
	normal.xyz= normalize(normal.xyz);
	float3 light_dir= normalize(p_vmf_lighting_constant_2.xyz);											// ###ctchou $TODO $PERF pass additional normalized version of this into shader
	float cosine= -dot(normal.xyz, light_dir);														// transform normal into 'lighting' space (only Z component - equivalent to normal dot lighting direction)
	
   	// compute the bump normal in local tangent space												// shadows do not currently respect bump
//	float3 bump_normal_in_tangent_space;
//	calc_bumpmap_ps(texcoord, bump_texcoord, bump_normal_in_tangent_space);
	// rotate bump to world space (same space as lightprobe) and normalize
//	float3 bump_normal= normalize( mul(bump_normal_in_tangent_space, tangent_frame) );
	
	float shadow_darkness;																			// ###ctchou $TODO pass this in (based on ambientness of the lightprobe)
	
	// compute shadow falloff as a function of the z depth (distance from front shadow volume plane), and the incident angle from lightsource (cosine falloff)
	float shadow_falloff= max(0.0f, fragment_shadow_position.z*2-1);								// shift z-depth falloff to bottom half of the shadow volume (no depth falloff in top half)
	shadow_falloff *= shadow_falloff;																// square depth
	shadow_darkness= k_ps_constant_shadow_alpha.r * (1-shadow_falloff*shadow_falloff) * max(0.0f, cosine);		// z_depth_falloff= 1 - (shifted_depth)^4,    incident_falloff= cosine lobe

	float darken= 1.0f;
	if (shadow_darkness > 0.001)																	// if maximum shadow darkness is zero (or very very close), don't bother doing the expensive PCF sampling
	{
		// calculate depth_bias (the maximum allowed depth_disparity within a single pixel)
		//		depth_bias = maximum_fragment_slope * half_pixel_size
		//      maximum fragment slope is the magnitude of the surface gradient with respect to shadow-space-Z (basically, glancing pixels have high slope)
		//      half pixel size is the distance in world space from the center of a shadow pixel to a corner (dotted line in diagram)
		//          ___________
		//         |         .'|
		//         |       .'  |
		//         |     .'    |
		//         |           |
		//         |___________|
		//
		//		the basic idea is:  we know the current fragment is within half_pixel_size of the center of this pixel in the shadow projection
		//							the depth map stores the Z value of the center of the pixel, we want to determine what the Z value is at our projection
		//							our simple approximation is to assume it is at the farthest point in the pixel, and do the compare at that point
		
		float slope= sqrt(1-cosine*cosine) / cosine;												// slope == tan(theta) == sin(theta)/cos(theta) == sqrt(1-cos^2(theta))/cos(theta)
		slope= min(slope, 4.0f) + 0.2f;																// don't let slope get too big (results in shadow errors - see master chief helmet), add a little bit of slope to account for curvature
																									// ###ctchou $REVIEW could make this (4.0) a shader parameter if you have trouble with the masterchief's helmet not shadowing properly	
		float half_pixel_size= p_vmf_lighting_constant_3.x;												// the texture coordinate distance from the center of a pixel to the corner of the pixel
		float depth_bias= slope * half_pixel_size;

		// sample shadow depth
		float percentage_closer= sample_percentage_closer_PCF_3x3_block(fragment_shadow_position, depth_bias);
	
		// compute darkening
		darken= 1-shadow_darkness + percentage_closer * shadow_darkness;
		darken*= darken;
	}
//	else
//	{
//		clip(-1.0f);		// DEBUG - to clip regions that aren't calculated						// ###ctchou $TODO $PERF - putting this clip in might improve performance if we're alpha-blend bound (unlikely)
//	}
	
	
	// the destination contains (pixel * extinction + inscatter) - we want to change it to (pixel * darken * extinction + inscatter)
	// so we multiply by darken (aka src alpha), and add inscatter * (1-darken)
	return convert_to_render_target(float4(inscatter*g_exposure.rrr, darken), true, false);
*/
	return convert_to_render_target(float4(0.0f, 0.0f, 0.0f, 1.0f), false, false);
}
