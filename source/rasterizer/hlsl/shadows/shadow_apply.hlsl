////#line 2 "source\rasterizer\hlsl\shadow_apply.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"

#include "templated\deform.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"

#ifndef SAMPLE_PERCENTAGE_CLOSER
#define SAMPLE_PERCENTAGE_CLOSER sample_percentage_closer_PCF_3x3_block
#endif // SAMPLE_PERCENTAGE_CLOSER

sampler zbuffer : register(s0);
sampler shadow : register(s1);
sampler normal_buffer : register(s2);


#define CAMERA_TO_SHADOW_PROJECTIVE_X	p_lighting_constant_0
#define CAMERA_TO_SHADOW_PROJECTIVE_Y	p_lighting_constant_1
#define CAMERA_TO_SHADOW_PROJECTIVE_Z	p_lighting_constant_2

#define INSCATTER_SCALE					p_lighting_constant_3
#define INSCATTER_OFFSET				p_lighting_constant_4

#define CHANNEL_TRANSFORM				p_lighting_constant_5

#define zbuffer_xform					p_lighting_constant_6
#define screen_xform					p_lighting_constant_7

#define ZBUFFER_SCALE					(p_lighting_constant_8.r)
#define ZBUFFER_BIAS					(p_lighting_constant_8.g)
#define SHADOW_PIXELSIZE				(p_lighting_constant_8.b)
#define ZBUFFER_PIXELSIZE				(p_lighting_constant_8.a)

#define SHADOW_DIRECTION_WORLDSPACE		(p_lighting_constant_9.xyz)


PIXEL_CONSTANT(float4x4, k_ps_view_xform_inverse, c213);

//@generate tiny_position
//@entry default
//@entry albedo


#include "shared\render_target.fx"


#ifdef pc
const float2 pixel_size= float2(1.0/512.0f, 1.0/512.0f);		// shadow pixel size ###ctchou $TODO THIS NEEDS TO BE PASSED IN!!!  good thing we don't care about PC...
#endif
#include "shared\texture.fx"


#include "shared\texture_xform.fx"

// default for hard shadow
void default_vs(
	in vertex_type vertex,
	out float4 screen_position : POSITION)
{
    float4 local_to_world_transform[3];
	if (always_true)
	{
		deform(vertex, local_to_world_transform);
	}
	
	if (always_true)
	{
		screen_position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
	}
	else
	{
		screen_position= float4(0,0,0,0);
	}
}


float sample_percentage_closer_PCF_3x3_block(float3 fragment_shadow_position, float depth_bias)					// 9 samples, 0 predicated
{
#ifndef pc
	[isolate]		// optimization - reduces GPRs
#endif // !pc

	float2 texel= fragment_shadow_position.xy;

	float4 blend= 1.0f;
	float scale= 1.0f / 9.0f;
	
#ifdef BILINEAR_SHADOWS
#ifndef VERTEX_SHADER
	asm {
		getWeights2D blend.xy, fragment_shadow_position.xy, shadow, MagFilter=linear, MinFilter=linear, OffsetX=0.5, OffsetY=0.5
	};
	blend.zw= 1.0f - blend.xy;
	scale = 1.0f / 4.0f;
#endif // VERTEX_SHADER
#endif // BILINEAR_SHADOWS
	
	float4 max_depth= depth_bias;											// x= [0,0],    y=[-1/1,0] or [0,-1/1],     z=[-1/1,-1/1],		w=[-2/2,0] or [0,-2/2]
	max_depth *= float4(-1.0f, -sqrt(20.0f), -3.0f, -sqrt(26.0f));			// make sure the comparison depth is taken from the very corner of the samples (maximum possible distance from our central point)
	max_depth += fragment_shadow_position.z;
	
	float color=	blend.z * blend.w * step(max_depth.z, tex2D_offset_point(shadow, texel, -1.0f, -1.0f).r) + 
					1.0f    * blend.w * step(max_depth.y, tex2D_offset_point(shadow, texel, +0.0f, -1.0f).r) +
					blend.x * blend.w * step(max_depth.z, tex2D_offset_point(shadow, texel, +1.0f, -1.0f).r) +
					blend.z * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel, -1.0f, +0.0f).r) +
					1.0f    * 1.0f    * step(max_depth.x, tex2D_offset_point(shadow, texel, +0.0f, +0.0f).r) +
					blend.x * 1.0f    * step(max_depth.y, tex2D_offset_point(shadow, texel, +1.0f, +0.0f).r) +
					blend.z * blend.y * step(max_depth.z, tex2D_offset_point(shadow, texel, -1.0f, +1.0f).r) +
					1.0f    * blend.y * step(max_depth.y, tex2D_offset_point(shadow, texel, +0.0f, +1.0f).r) +
					blend.x * blend.y * step(max_depth.z, tex2D_offset_point(shadow, texel, +1.0f, +1.0f).r);
					
	return color * scale;
}


accum_pixel default_ps(
	in float2 pixel_pos : VPOS)
{
#ifdef pc
	float2 texture_pos= transform_texcoord(pixel_pos.xy, zbuffer_xform);
#else
	pixel_pos.xy += p_tiling_vpos_offset.xy;
	float2 texture_pos= transform_texcoord(pixel_pos.xy, zbuffer_xform);
#endif
	
//*
	float pixel_depth= tex2D(zbuffer, texture_pos).r;
	pixel_depth= 1.0f / (pixel_depth * ZBUFFER_SCALE + ZBUFFER_BIAS);					// convert to 'true' depth		(z)

	// calculate projected screen position
	float4 screen_position= float4(transform_texcoord(pixel_pos.xy, screen_xform) * pixel_depth, pixel_depth, 1.0f);

	// GRADIENT NORMAL - not used cuz we have normal buffers now
//	float4 fragment_shadow_position;
//	fragment_shadow_position.x= dot(screen_position, CAMERA_TO_SHADOW_X);
//	fragment_shadow_position.y= dot(screen_position, CAMERA_TO_SHADOW_Y);
//	fragment_shadow_position.z= dot(screen_position, CAMERA_TO_SHADOW_Z);
//	fragment_shadow_position.w= 1.0f;

//	float3 shadow_gradient_x= ddx(fragment_shadow_position.xyz);
//	float3 shadow_gradient_y= ddy(fragment_shadow_position.xyz);
//	float3 normal_shadow_space= normalize(cross(shadow_gradient_y, shadow_gradient_x));
//	float cosine= normal_shadow_space.z;


	// NOTE: if we want projective shadows, do this dot product and divide x,y,z by w
	float3 fragment_shadow_projected;
	fragment_shadow_projected.x= dot(screen_position, CAMERA_TO_SHADOW_PROJECTIVE_X);				
	fragment_shadow_projected.y= dot(screen_position, CAMERA_TO_SHADOW_PROJECTIVE_Y);
	fragment_shadow_projected.z= dot(screen_position, CAMERA_TO_SHADOW_PROJECTIVE_Z);

/*/
	// ###ctchou $TODO this is much more optimal
	float pixel_depth= tex2D(zbuffer, texture_pos).r;
	float4 position_projective= float4(pixel_pos.xy, pixel_depth, 1.0f);
	float4 position_shadow_projective= mul(position_projective, transpose(k_ps_view_xform_inverse));
	float3 fragment_shadow_projected=	position_shadow_projective.xyz / position_shadow_projective.w;

//*/

	float3 normal_world_space= tex2D(normal_buffer, texture_pos).xyz * 2.0f - 1.0f;										// ###ctchou $PERF bias this in the texture format
	float cosine= dot(normal_world_space, SHADOW_DIRECTION_WORLDSPACE.xyz);

	float shadow_falloff= saturate(fragment_shadow_projected.z*2-1);													// shift z-depth falloff to bottom half of the shadow volume (no depth falloff in top half)
	shadow_falloff *= shadow_falloff;																					// square depth
	
	// we mask out the incident radiance in the static pass	
	// so we don't need to calculate lighting here.
	// what we need is to kill the light that is facing away from the direction.
//	float cosine_falloff= saturate(0.75f + cosine*4);
	float cosine_falloff= saturate(0.65f + cosine*5);		// push the shadow line slightly past 180 degrees, otherwise we get a bright edge of analytical around the horizon.   this also gives us slightly more shadow boundary problems, but what ya gonna do?
//	float cosine_falloff= saturate(cosine*5);
		
	float shadow_darkness= k_ps_constant_shadow_alpha.r * (1-shadow_falloff*shadow_falloff) * cosine_falloff;			// z_depth_falloff= 1 - (shifted_depth)^4,    incident_falloff= cosine lobe

	float darken= 1.0f;
#ifndef pc
	[predicateBlock]
//	[predicate]
//	[branch]
#endif // !pc
	if (shadow_darkness > 0.001)		// if maximum shadow darkness is zero (or very very close), don't bother doing the expensive PCF sampling
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
		
#ifndef FASTER_SHADOWS
		cosine= max(cosine, 0.24253562503633297351890646211612);									// limits max slope to 4.0, and prevents divide by zero  ###ctchou $REVIEW could make this (4.0) a shader parameter if you have trouble with the masterchief's helmet not shadowing properly
		float slope= sqrt(1-cosine*cosine) / cosine;												// slope == tan(theta) == sin(theta)/cos(theta) == sqrt(1-cos^2(theta))/cos(theta)
		slope= slope + 0.2f;
#else
		float slope= 0.0f;
#endif // FASTER_SHADOWS

		float half_pixel_size= SHADOW_PIXELSIZE;													// the texture coordinate distance from the center of a pixel to the corner of the pixel
		float depth_bias= slope * half_pixel_size;
	
		// sample shadow depth
		float percentage_closer= SAMPLE_PERCENTAGE_CLOSER(fragment_shadow_projected.xyz, depth_bias);		// 
		
		// compute darkening
		darken= saturate(1.01-shadow_darkness + percentage_closer * shadow_darkness);		// 1.001 to fix round off error..  (we want to ensure we output at least 1.0 when percentage_closer= 1, not 0.9999)
		darken *= darken;
	}

	accum_pixel result;
	result.color=float4(darken, 0, 0, darken) * CHANNEL_TRANSFORM.xxxy + CHANNEL_TRANSFORM.zzzw;
#ifndef LDR_ONLY	
	result.dark_color=0;
#endif
	
    return result;
}


// albedo for ambient blur shadow

void albedo_vs(
	in vertex_type vertex,
	out float4 screen_position : POSITION)
{
    float4 local_to_world_transform[3];
	if (always_true)
	{
		deform(vertex, local_to_world_transform);
	}
	
	if (always_true)
	{
		screen_position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
	}
	else
	{
		screen_position= float4(0,0,0,0);
	}
}


#ifndef pc

#define k_register_occlusion_sphere_count			i1
#define k_register_view_inverse_matrix				c100
#define k_register_occlusion_sphere_start			c114

#define k_maximum_occlusion_sphere_count			20
#define k_occlusion_sphere_stride					2
PIXEL_CONSTANT(float4x4, view_inverse_matrix, k_register_view_inverse_matrix);
PIXEL_CONSTANT(float4, occlusion_spheres[k_maximum_occlusion_sphere_count * k_occlusion_sphere_stride], k_register_occlusion_sphere_start); 
PIXEL_CONSTANT(int, occlusion_spheres_count, k_register_occlusion_sphere_count);

#define		SPHERE_DATA(index, offset, registers)	occlusion_spheres[index + offset].registers
#define		SPHERE_CENTER(index)			SPHERE_DATA(index, 0, xyz)
#define		SPHERE_AXIS(index)				SPHERE_DATA(index, 1, xyz)
#define		SPHERE_RADIUS_SHORTER(index)	SPHERE_DATA(index, 0, w)
#define		SPHERE_RADIUS_LONGER(index)		SPHERE_DATA(index, 1, w)

accum_pixel albedo_ps(
	in float2 pixel_pos : VPOS)
{
	// get world position of current pixel	
	pixel_pos.xy += p_tiling_vpos_offset.xy;
	float2 texture_pos= transform_texcoord(pixel_pos.xy, zbuffer_xform);	
	
	float pixel_depth= tex2D(zbuffer, texture_pos).r;
	float4 world_position= float4(transform_texcoord(pixel_pos.xy, screen_xform), pixel_depth, 1.0f);	
//	world_position= mul(world_position, transpose(view_inverse_matrix));		// ###ctchou $TODO this is much more optimal
	world_position= mul(world_position, view_inverse_matrix);
	world_position.xyz/= world_position.w;

	float percentage_closer= 1.0f;
	[loop]
	for (int sphere_index= 0; sphere_index < occlusion_spheres_count; sphere_index++)
	{
		//float3 sphere_center= SPHERE_CENTER(sphere_index);
		float3 ellipse_center= SPHERE_CENTER(sphere_index);
		float3 ellipse_axis= SPHERE_AXIS(sphere_index);
		float ellipse_radius_shorter= SPHERE_RADIUS_SHORTER(sphere_index);
		float ellipse_radius_longer= SPHERE_RADIUS_LONGER(sphere_index);

		float3 center_to_pixel_direction= ellipse_center-world_position.xyz;		
		float center_to_pixel_distance= length(center_to_pixel_direction);

		// darken by distance along light path
		float darken= 0.0f;
		{
			float3 light_to_cent= cross(center_to_pixel_direction, SHADOW_DIRECTION_WORLDSPACE);
			float light_to_cent_length= length(light_to_cent);

			// normalize light to center vector
			light_to_cent/= light_to_cent_length;
			float along_axis= abs( dot(light_to_cent, ellipse_axis) );
			float radius= lerp(ellipse_radius_shorter, ellipse_radius_longer, along_axis);

			// compute darken			
			float ratio= max(light_to_cent_length / radius, 0.5f);
			//ratio= sqrt(ratio);
			darken= saturate( 1.0f - 0.3f * ratio);		
		}

		// influence by distance and normal direction
		float influence= 0.0f;
		{
			// normalize direction
			center_to_pixel_direction/= center_to_pixel_distance;
			float radius= ellipse_radius_shorter;

			// compute influence			
			//influence= saturate(radius / center_to_pixel_distance);			
			influence= saturate(1.0f - 0.2f * center_to_pixel_distance / radius);			
			//influence*= influence;

			float avoid_self_shadow= saturate(-0.2f + 1.2f*dot(center_to_pixel_direction, SHADOW_DIRECTION_WORLDSPACE));
			influence*= avoid_self_shadow ;
		}

		//percentage_closer= min(percentage_closer, 1.0f - darken * influence);
		percentage_closer*= 1.0f - darken * influence;
	}

	float3 normal_world_space= tex2D(normal_buffer, texture_pos).xyz * 2.0f - 1.0f;										// ###ctchou $PERF bias this in the texture format
	float cosine= dot(normal_world_space, SHADOW_DIRECTION_WORLDSPACE.xyz);
	float shadow_darkness= k_ps_constant_shadow_alpha.r * saturate(0.6f + 0.4f * cosine);			// z_depth_falloff= 1 - (shifted_depth)^4,    incident_falloff= cosine lobe

	//float shadow_darkness= k_ps_constant_shadow_alpha.r * 0.8;
	

	float darken= 1.0f;
	if (shadow_darkness > 0.001)		// if maximum shadow darkness is zero (or very very close), don't bother doing the expensive PCF sampling
	{		
		// compute darkening
		darken= saturate(1.01-shadow_darkness + percentage_closer * shadow_darkness);		// 1.001 to fix round off error..  (we want to ensure we output at least 1.0 when percentage_closer= 1, not 0.9999)
		darken*= darken;
	}	

	// compute inscatter
	float3 inscatter= -pixel_depth * INSCATTER_SCALE + INSCATTER_OFFSET;

	// the destination contains (pixel * extinction + inscatter) - we want to change it to (pixel * darken * extinction + inscatter)
	// so we multiply by darken (aka src alpha), and add inscatter * (1-darken)
	return convert_to_render_target(float4(inscatter * g_exposure.rrr, darken), false, true);		// Note: the (inscatter*(1-darken)) clamping is not correct, but only when the inscatter is HDR already - in which case you can't see anything anyways
	// ###ctchou $PERF multiply inscatter by g_exposure before passing to this shader  :)
}

#else

accum_pixel albedo_ps(
	in float2 pixel_pos : VPOS)
{
	return convert_to_render_target(float4(0.0f, 0.0f, 0.0f, 0.0f), false, true);
}

#endif