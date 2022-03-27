/*
WATER_SHADING.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

//#include "shared\atmosphere.fx"
#include "shared\texture_xform.fx"
//#include "shared\blend.fx"
#include "templated\bump_mapping.fx"
#include "lights\simple_lights.fx"
#include "templated\lightmap_sampling.fx"
#include "shared\spherical_harmonics.fx"
#include "templated\debug_modes.fx"


/* vertex shader implementation */
#ifdef VERTEX_SHADER

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
// We could automatically prepend this to the shader file when doing generate-templates, hmmm...
#ifndef category_global_shape
extern int category_global_shape;
#endif

#ifndef category_waveshape
extern int category_waveshape;
#endif

float4 barycentric_interpolate(
			float4 a,
			float4 b,
			float4 c,
			float3 weights)
{
	return a*weights.z + b*weights.y + c*weights.x;
}

// interpolate vertex porperties accroding tesselation information
s_water_render_vertex get_tessellated_vertex( s_vertex_type_water_shading IN )
{
	s_water_render_vertex OUT;

	// indices of vertices
	int index= IN.index + k_vs_water_index_offset.x;
	float4 v_index0, v_index1, v_index2;
	asm {
		vfetch v_index0, index, color0
		vfetch v_index1, index, color1
		vfetch v_index2, index, color2
	};

	//	fetch vertex porpertices
	float4 pos0, pos1, pos2;
	float4 tex0, tex1, tex2;
	float4 nml0, nml1, nml2;
	float4 tan0, tan1, tan2;	
	float4 btex0, btex1, btex2;
	float4 lm_tex0, lm_tex1, lm_tex2;
	

	int v0_index_mesh= v_index0.x;
	int v0_index_water= v_index0.y;

	int v1_index_mesh= v_index1.x;
	int v1_index_water= v_index1.y;

	int v2_index_mesh= v_index2.x;
	int v2_index_water= v_index2.y;

	asm {
		vfetch pos0, v0_index_mesh, position0
		vfetch tex0, v0_index_mesh, texcoord0
		vfetch nml0, v0_index_mesh, normal0
		vfetch tan0, v0_index_mesh, tangent0
		vfetch lm_tex0, v0_index_mesh, texcoord1
		vfetch btex0, v0_index_water, position1

		vfetch pos1, v1_index_mesh, position0
		vfetch tex1, v1_index_mesh, texcoord0
		vfetch nml1, v1_index_mesh, normal0
		vfetch tan1, v1_index_mesh, tangent0
		vfetch lm_tex1, v1_index_mesh, texcoord1
		vfetch btex1, v1_index_water, position1

		vfetch pos2, v2_index_mesh, position0
		vfetch tex2, v2_index_mesh, texcoord0
		vfetch nml2, v2_index_mesh, normal0
		vfetch tan2, v2_index_mesh, tangent0
		vfetch lm_tex2, v2_index_mesh, texcoord1
		vfetch btex2, v2_index_water, position1
	};

	// re-order the weights based on the QuadID
	float3 weights= IN.uvw * (0==IN.quad_id);
	weights+= IN.uvw.zxy * (1==IN.quad_id);
	weights+= IN.uvw.yzx * (2==IN.quad_id); 
	weights+= IN.uvw.xzy * (4==IN.quad_id); 
	weights+= IN.uvw.yxz * (5==IN.quad_id);
	weights+= IN.uvw.zyx * (6==IN.quad_id);

	// interpoate otuput		
	OUT.position= barycentric_interpolate(pos0, pos1, pos2, weights);
	OUT.texcoord= barycentric_interpolate(tex0, tex1, tex2, weights);

	OUT.normal= barycentric_interpolate(nml0, nml1, nml2, weights);
	OUT.tangent= barycentric_interpolate(tan0, tan1, tan2, weights);
	
	OUT.base_tex= barycentric_interpolate(btex0, btex1, btex2, weights);
	OUT.lm_tex= barycentric_interpolate(lm_tex0, lm_tex1, lm_tex2, weights);
	

	OUT.normal= normalize(OUT.normal);
	OUT.tangent= normalize(OUT.tangent);
	OUT.binormal= float4(cross(OUT.normal.xyz, OUT.tangent.xyz), 0);
	OUT.position.w= 1.0f;
	OUT.vmf_intensity= 1.0f;

	return OUT;
}

// get vertex properties
s_water_render_vertex get_vertex( 
	s_vertex_type_water_shading IN,
	const bool has_per_vertex_lighting)
{
	s_water_render_vertex OUT;

	// indices of vertices			
	float in_index= IN.uvw.x; // ###xwan after declaration of uvw and quad_id, Xenon has mistakely put index into uvw.x. :-(
	int t_index;
	[isolate]
	{
		t_index= floor((in_index+0.3f)/3);	//	triangle index		
	}

	int v_guid;
	[isolate]
	{
		float temp= in_index - t_index*3 + 0.1f;
		v_guid= (int) temp;
	}

	float4 v_index0, v_index1, v_index2;	
	asm {
		vfetch v_index0, t_index, color0
		vfetch v_index1, t_index, color1
		vfetch v_index2, t_index, color2
	};

	float4 v_index= v_index0 * (0==v_guid);
	v_index+= v_index1 * (1==v_guid);
	v_index+= v_index2 * (2==v_guid);	
	

	//	fetch vertex porpertices
	float4 pos, tex, nml, tan, bnl, btex, loc, lm_tex;
	int v_index_mesh= v_index.x;
	int v_index_water= v_index.y;

	asm {
		vfetch pos, v_index_mesh, position0
		vfetch tex, v_index_mesh, texcoord0
		vfetch nml, v_index_mesh, normal0
		vfetch tan, v_index_mesh, tangent0
		vfetch lm_tex, v_index_mesh, texcoord1
		vfetch btex, v_index_water, position1
		
	};

	if (has_per_vertex_lighting)
	{
	    float4 vmf_light0;
		float4 vmf_light1;
	    
		int vertex_index_after_offset= v_index_mesh - per_vertex_lighting_offset.x;
		fetch_stream(vertex_index_after_offset, vmf_light0, vmf_light1);
	 
		float4 vmf0, vmf1, vmf2, vmf3;
		decompress_per_vertex_lighting_data(vmf_light0, vmf_light1, vmf0, vmf1, vmf2, vmf3);

		OUT.vmf_intensity= vmf1.rgb + vmf0.a;
	}
	else
	{
		OUT.vmf_intensity= 0;
	}
	
	// interpoate otuput
	OUT.position= pos;
	OUT.texcoord= tex;
	OUT.normal= nml;
	OUT.tangent= tan;
	OUT.binormal= float4(cross(OUT.normal, OUT.tangent), 0);
	
	OUT.base_tex= btex;
	OUT.lm_tex= lm_tex;
	OUT.position.w= 1.0f;
	return OUT;
}

float3 restore_displacement(
			float3 displacement,
			float height)
{
	displacement= displacement*2.0f - 1.0f;
	displacement*= height;
	return displacement;
}

float3 apply_choppiness(
			float3 displacement,			
			float chop_forward,
			float chop_backward,
			float chop_side)
{	
	displacement.y*= chop_side;	//	backward choppiness
	displacement.x*= (displacement.x<0) ? chop_forward : chop_backward; //forward scale, y backword scale		
	return displacement;
}

float2 calculate_ripple_coordinate_by_world_position(
			float2 position)
{
	float2 texcoord_ripple= (position - Camera_Position.xy) / k_ripple_buffer_radius;		
	float len= length(texcoord_ripple);		
	texcoord_ripple*= rsqrt(len);		

	texcoord_ripple+= k_view_dependent_buffer_center_shifting;
	texcoord_ripple= texcoord_ripple*0.5f + 0.5f;
	texcoord_ripple= saturate(texcoord_ripple);
	return texcoord_ripple;
}
			

// transform vertex position, normal etc accroding to wave 
s_water_interpolators transform_vertex( 
	s_water_render_vertex IN,
	const bool has_per_vertex_lighting)
{	
	//	vertex to eye displacement
	float4 incident_ws;
	incident_ws.xyz= Camera_Position - IN.position.xyz;		
	incident_ws.w= length(incident_ws.xyz);
	incident_ws.xyz= normalize(incident_ws.xyz);
	float mipmap_level= max(incident_ws.w / wave_visual_damping_distance, 0.0f); 		

	// apply global shape control
	float height_scale_global= 1.0f;
	float choppy_scale_global= 1.0f;
	if (TEST_CATEGORY_OPTION(global_shape, paint))
	{
		float4 shape_control= tex2Dlod(global_shape_texture, float4(transform_texcoord(IN.base_tex.xy, global_shape_texture_xform), 0, mipmap_level));
		height_scale_global= shape_control.x;
		choppy_scale_global= shape_control.y;
	}

	// calculate displacement of vertex
	float4 position= IN.position;

	float4 original_texcoord= IN.texcoord;
	float2 texcoord_ripple= 0.0f;	
	
	if (k_is_water_tessellated)	
	{			
		float3 displacement= 0.0f;
		if (TEST_CATEGORY_OPTION(waveshape, default))
		{	
			//	re-assemble constants
			float4 texcoord= float4(transform_texcoord(original_texcoord.xy, wave_displacement_array_xform),  time_warp, mipmap_level);		
			float4 texcoord_aux= float4(transform_texcoord(original_texcoord.xy, wave_slope_array_xform),  time_warp_aux, mipmap_level);

			// dirty hack to work around the texture fetch bug of screenshot on Xenon			
			if ( k_is_under_screenshot ) 
			{
				texcoord.w= 0.0f;
				texcoord_aux.w= 0.0f;
			}

			displacement= tex3Dlod(wave_displacement_array, texcoord).xyz;			
			float3 displacement_aux= tex3Dlod(wave_displacement_array, texcoord_aux).xyz;		
			//float3 displacement_aux= 0.0f;
			

			// restore displacement
			displacement= restore_displacement(
								displacement,
								wave_height);

			displacement_aux= restore_displacement(
								displacement_aux,
								wave_height_aux);

			displacement= displacement + displacement_aux;

			displacement= apply_choppiness(
								displacement,
								choppiness_forward * choppy_scale_global,
								choppiness_backward * choppy_scale_global, 
								choppiness_side * choppy_scale_global);

			// apply global height control
			displacement.z*= height_scale_global;
		}

		// get ripple texcoord		
		if (k_is_water_interaction)
		{			
			texcoord_ripple= (IN.position.xy - Camera_Position.xy) / k_ripple_buffer_radius;		
			float len= length(texcoord_ripple);		
			texcoord_ripple*= rsqrt(len);		

			texcoord_ripple+= k_view_dependent_buffer_center_shifting;
			texcoord_ripple= texcoord_ripple*0.5f + 0.5f;
			texcoord_ripple= saturate(texcoord_ripple);
		}

		// apply vertex displacement
		position+= 
			IN.tangent *displacement.x +
			IN.binormal *displacement.y + 
			IN.normal *displacement.z;
		

		// consider interaction	after displacement
		if (k_is_water_interaction)
		{
			texcoord_ripple= calculate_ripple_coordinate_by_world_position(position.xy);
			float4 ripple_hei= tex2Dlod(tex_ripple_buffer_slope_height, float4(texcoord_ripple.xy, 0, 0));		
			
			float ripple_height= ripple_hei.r*2.0f - 1.0f;			
			ripple_height*= 0.2f;	//	maximune disturbance of water is 5 inchs

			// low down ripple for shallow water
			ripple_height*= height_scale_global;

			position+= IN.normal * ripple_height;
		}

		position.w= 1.0f;	
	}	
	else
	{
		// get ripple texcoord		
		if (k_is_water_interaction)
		{			
			texcoord_ripple= calculate_ripple_coordinate_by_world_position(IN.position.xy);
		}
	}

	////	computer atmosphere fog
	//float3 fog_extinction;
	//float3 fog_inscatter;
	//compute_scattering(Camera_Position, position.xyz, fog_extinction, fog_inscatter);
	

	s_water_interpolators OUT;
	//OUT.position= mul( position, k_vs_water_view_xform );	//View_Projection
	
	OUT.position= mul( position, View_Projection );
	OUT.texcoord= float4(original_texcoord.xyz, mipmap_level);
	OUT.normal= IN.normal;
	OUT.tangent= IN.tangent;
	OUT.binormal= IN.binormal;		//	hack hack from LH to RH


//	OUT.position_ss= OUT.position;
	OUT.position_ss= OUT.position * float4(0.5f, -0.5f, 1.0f, 1.0f) + float4(0.5f, 0.5f, 0.0f, 0.0f) * OUT.position.w;

	OUT.incident_ws= incident_ws;
	OUT.position_ws= float4(position.xyz, 1.0f/max(incident_ws.w, 0.01f)); // one_over_camera_distance

	OUT.base_tex= 
		float4(IN.base_tex.xy, texcoord_ripple);

	if (has_per_vertex_lighting)
	{
		OUT.lm_tex= float4(IN.vmf_intensity, 0.0f);		
	}
	else
	{
		OUT.lm_tex= float4(IN.lm_tex.xy, 0, 0);
	}

	return OUT;
}

#endif //VERTEX_SHADER



/* pixel shader implementation */
#ifdef PIXEL_SHADER

float2 compute_detail_slope(
			float2 base_texcoord,
			float4 base_texture_xform,
			float time_warp,
			float mipmap_level)
{
	float2 slope_detail= 0.0f;		
	if ( TEST_CATEGORY_OPTION(detail, repeat) )
	{
		float4 wave_detail_xform= base_texture_xform * float4(detail_slope_scale_x, detail_slope_scale_y, 1, 1);
		float4 texcoord_detail= float4(transform_texcoord(base_texcoord, wave_detail_xform),  time_warp*detail_slope_scale_z, mipmap_level);	
		asm
		{
			tfetch3D slope_detail.xy, texcoord_detail.xyz, wave_slope_array, MagFilter= linear, MinFilter= linear, MipFilter= linear, VolMagFilter= linear, VolMinFilter= linear
		};
		slope_detail.xy *= detail_slope_steepness;
	}

	return slope_detail;
}


void compose_slope_default(
			float4 texcoord_in,
			float height_scale,			// 1.0f
			float height_aux_scale,		// 1.0f
			out float2 slope_shading,
			out float wave_choppiness_ratio)
{
	float mipmap_level= texcoord_in.w;
	float4 texcoord= float4(transform_texcoord(texcoord_in.xy, wave_displacement_array_xform),  time_warp, mipmap_level);

	float2 slope;
	asm
	{
		tfetch3D slope.xy, texcoord.xyz, wave_slope_array, MagFilter= linear, MinFilter= linear, MipFilter= linear, VolMagFilter= linear, VolMinFilter= linear
	};

	wave_choppiness_ratio= 1.0f - abs(slope.x) - abs(slope.y);

	float2 slope_detail= compute_detail_slope(texcoord_in.xy, wave_displacement_array_xform, time_warp, mipmap_level+1);

	//	apply scale		
	slope_shading=	slope + slope_detail;
}


void compose_slope_original(
			float4 texcoord_in,
			float height_scale,
			float height_aux_scale,
			out float2 slope_shading,
			out float wave_choppiness_ratio)
{
	float mipmap_level= texcoord_in.w;	
	float4 texcoord= float4(transform_texcoord(texcoord_in.xy, wave_displacement_array_xform),  time_warp, mipmap_level);
	float4 texcoord_aux= float4(transform_texcoord(texcoord_in.xy, wave_slope_array_xform),  time_warp_aux, mipmap_level);	

	float2 slope;
	float2 slope_aux;	

	asm{
		tfetch3D slope.xy, texcoord.xyz, wave_slope_array, MagFilter= linear, MinFilter= linear, MipFilter= linear, VolMagFilter= linear, VolMinFilter= linear
		tfetch3D slope_aux.xy, texcoord_aux.xyz, wave_slope_array, MagFilter= linear, MinFilter= linear, MipFilter= linear, VolMagFilter= linear, VolMinFilter= linear
	};


	float wave_choppiness_ratio_1= 1.0f - abs(slope.x) - abs(slope.y);
	float wave_choppiness_ratio_2= 1.0f - abs(slope_aux.x) - abs(slope_aux.y);
	wave_choppiness_ratio= max(wave_choppiness_ratio_1, wave_choppiness_ratio_2);

	float2 slope_detail= compute_detail_slope(texcoord_in.xy, wave_displacement_array_xform, time_warp, mipmap_level+1);

	//	apply scale		
	slope_shading= 	slope + slope_aux + slope_detail;
}


// fresnel approximation
float compute_fresnel(
			float3 incident,
			float3 normal,
			float r0,
			float r1)
{
 	float eye_dot_normal=	saturate(dot(incident, normal));
	eye_dot_normal=			saturate(r1 - eye_dot_normal);
	return saturate(r0 * eye_dot_normal * eye_dot_normal);			//pow(eye_dot_normal, 2.5);
}

float compute_fog_transparency( 
			float murkiness,
			float negative_depth)
{
	return saturate(exp2(murkiness * negative_depth));
}


float compute_fog_factor( 
			float murkiness,
			float depth)
{
	return 1.0f - compute_fog_transparency(murkiness, -depth);
}

float3 decode_bpp16_luvw(
	in float4 val0,
	in float4 val1,
	in float l_range)
{	
	float L = val0.a * val1.a * l_range;
	float3 uvw = val0.xyz + val1.xyz;
	return (uvw * 2.0f - 2.0f) * L;	
}


float sample_depth(float2 texcoord)
{
#ifdef pc
	return tex2D(depth_buffer, texcoord).r;
#else // xenon
	float4 result;
	asm
	{
		tfetch2D result, texcoord, depth_buffer, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= 0.5, OffsetY= 0.5
	};
	return result.r;
#endif // xenon
}


//#define USE_LOD_SAMPLER false;

// shade water surface
accum_pixel water_shading(
	s_water_interpolators INTERPOLATORS,
	uniform const bool has_per_vertex_lighting,
	uniform const bool alpha_blend_output)			// actually uses multiply-add blend mode if true
{			
	// interaction
	float2 ripple_slope= 0.0f;		
	float ripple_foam_factor= 0.0f;
	[branch]
	if (k_is_water_interaction)
	{			
		float2 texcoord_ripple= INTERPOLATORS.base_tex.zw;		
		float4 ripple;
		asm {tfetch2D ripple, texcoord_ripple, tex_ripple_buffer_slope_height, MagFilter= linear, MinFilter= linear};
		ripple_slope= (ripple.gb - 0.5f) * 6.0f;	// hack		
		ripple_foam_factor= ripple.a;
	}	

	float ripple_slope_length= dot(abs(ripple_slope.xy), 2.0f) + 1.0f;

	float2 slope_shading= 0.0f;
	float wave_choppiness_ratio= 0.0f;
	if (TEST_CATEGORY_OPTION(waveshape, default))
	{
		compose_slope_original(
			INTERPOLATORS.texcoord, 
			1.0f,
			1.0f,
			slope_shading,
			wave_choppiness_ratio);
	}
	else if (TEST_CATEGORY_OPTION(waveshape, bump) )
	{
		// grap code from calc_bumpmap_detail_ps in bump_mapping.fx
		float3 bump= sample_bumpmap(bump_map, transform_texcoord(INTERPOLATORS.texcoord, bump_map_xform));					// in tangent space
		float3 detail= sample_bumpmap(bump_detail_map, transform_texcoord(INTERPOLATORS.texcoord, bump_detail_map_xform));	// in tangent space	
		bump.xy+= detail.xy;

		// convert bump into slope
		slope_shading= bump.xy/max(bump.z, 0.01f);
	}
	slope_shading= slope_shading * slope_scaler + ripple_slope;

	float3x3 tangent_frame_matrix= { INTERPOLATORS.tangent.xyz, INTERPOLATORS.binormal.xyz, INTERPOLATORS.normal.xyz };
	float3 normal= mul(float3(slope_shading, 1.0f), tangent_frame_matrix);	
	normal= normalize(normal);	
	
/*
	// ###ctchou $PERF : add option for upward-facing unrotated tangent space water?
	float3 normal;
	normal.xy=	INTERPOLATORS.normal.xy + slope_shading;
	normal.z=	saturate(dot(normal.xy, normal.xy));
	normal.z=	sqrt(1 - normal.z);
*/
	// apply lightmap shadow
	float3 lightmap_intensity= 1.0f;
	
#ifndef pc
	if (has_per_vertex_lighting)
	{
		lightmap_intensity= INTERPOLATORS.lm_tex.rgb;
	}
	else
	{
		[branch]
		if (k_is_lightmap_exist)
		{
			const float2 lightmap_texcoord= INTERPOLATORS.lm_tex.xy;

			float4 vmf_coefficients[4];
			sample_lightprobe_texture(lightmap_texcoord, vmf_coefficients);

			// ###xwan it's a hack way, however, tons of content has been set by current water shaders. dangerous to change it	(###ctchou $NOTE:  I'll say)
			lightmap_intensity= 
				vmf_coefficients[1].rgb +		// Colors[0]*p_lightmap_compress_constant_0.x*fIntensity
				vmf_coefficients[0].a;			// sun visibility_mask
		}
	}
#endif //pc

	const float one_over_camera_distance= INTERPOLATORS.position_ws.w;	

	float4 water_color_from_texture= tex2D(watercolor_texture, transform_texcoord(INTERPOLATORS.base_tex.xy, watercolor_texture_xform));
	float4 global_shape_from_texture= tex2D(global_shape_texture, transform_texcoord(INTERPOLATORS.base_tex.xy, global_shape_texture_xform));

	float3 water_color;
	if (TEST_CATEGORY_OPTION(watercolor, pure))
	{
		water_color= water_color_pure;		
	}
	else if  (TEST_CATEGORY_OPTION(watercolor, texture))
	{
		water_color= water_color_from_texture.rgb * watercolor_coefficient;
	}
	water_color *= lightmap_intensity;

	float bank_alpha= 1.0f;
	if ( TEST_CATEGORY_OPTION(bankalpha, paint) )
	{
		bank_alpha= water_color_from_texture.w;
	}
	else if (TEST_CATEGORY_OPTION(bankalpha, from_shape_texture_alpha) )
	{
		bank_alpha= global_shape_from_texture.a;
	}
	
	float3 color_refraction;
	float3 color_refraction_bed;
	float4 color_refraction_blend;

	if (TEST_CATEGORY_OPTION(refraction, none))
	{
		color_refraction= water_color;
		color_refraction_bed= water_color;
		color_refraction_blend.rgb= water_color;
		color_refraction_blend.a=	0.0f;
	}
	else if (TEST_CATEGORY_OPTION(refraction, dynamic))
	{
		// calcuate texcoord in screen space
		INTERPOLATORS.position_ss /= INTERPOLATORS.position_ss.w;
		float2 texcoord_ss= INTERPOLATORS.position_ss.xy;
	
		float2 texcoord_refraction;
		float refraction_depth;
				
		if (alpha_blend_output)
		{
			texcoord_refraction= texcoord_ss;
			refraction_depth= sample_depth(texcoord_refraction);		
		}
		else
		{
			float2 bump= slope_shading.xy * refraction_texcoord_shift;
			bump *= saturate(2.0f*one_over_camera_distance);				// near bump fading -- could move to VS

			if (!TEST_CATEGORY_OPTION(bankalpha, none))
			{
				bump *= bank_alpha;
			}
		
			texcoord_refraction= saturate(texcoord_ss + bump);
			refraction_depth= sample_depth(texcoord_refraction);

			//	###xwan this comparision need to some tolerance to avoid dirty boundary of refraction	
			texcoord_refraction= (refraction_depth<INTERPOLATORS.position_ss.z) ? texcoord_refraction : texcoord_ss;				// if point is actually closer to camera, drop refraction amount and revert to unrefracted
//			texcoord_refraction= saturate(texcoord_ss + saturate(500*(INTERPOLATORS.position_ss.z - refraction_depth)) * bump);		// approximate depth fade out
		
			color_refraction= tex2D(scene_ldr_texture, texcoord_refraction);		
//			asm 
//			{		// this is more accurate and eliminates the very slight halos around objects in the refracted water..  but doesn't give as nice of a blend because we drop bilinear sampling
//				tfetch2D color_refraction.rgb_, texcoord_refraction, scene_ldr_texture, MagFilter= point, MinFilter= point, MipFilter= point, AnisoFilter= disabled, OffsetX= 0.5, OffsetY= 0.5
//			};
			
			color_refraction.rgb= (color_refraction.rgb < (1.0f/(16.0f*16.0f))) ? color_refraction.rgb : (exp2(color_refraction.rgb * (16 * 8) - 8));
			color_refraction/= g_exposure.r;
			color_refraction_bed= color_refraction;	//	pure color of under water stuff

			//	check real refraction -- we don't do this in the cheap shader because the apparent 'refraction' point doesn't move
			refraction_depth= sample_depth(texcoord_refraction);
		}

		float4 point_refraction= float4(texcoord_refraction, refraction_depth, 1.0f);
		point_refraction= mul(point_refraction, k_ps_texcoord_to_world_matrix);
		point_refraction.xyz/= point_refraction.w;

		// world space depth
//		float refraction_depth= INTERPOLATORS.position_ws.z - point_refraction.z;
		float negative_refraction_depth= point_refraction.z - INTERPOLATORS.position_ws.z;

		// compute refraction
//		float transparency= compute_fog_transparency(water_murkiness*ripple_slope_length, refraction_depth);		// what does ripple slope length accomplish?  attempt to darken ripple edges?
		float transparency= compute_fog_transparency(water_murkiness, negative_refraction_depth);
		transparency *= saturate(refraction_extinct_distance * one_over_camera_distance);							// turns opaque at distance
		
		if (k_is_camera_underwater)
		{
			transparency*= 0.02f;
		}
		
		if (alpha_blend_output)
		{
			color_refraction_blend.rgb= water_color.rgb * (1.0f - transparency);
			color_refraction_blend.a=	transparency;
		}
		else
		{
			color_refraction= lerp(water_color, color_refraction, transparency);
		}
	}	
	
	// compute foam	
	float4 foam_color= 0.0f;
	float foam_factor= 0.0f;	
	{
		// calculate factor
		float foam_factor_auto= 0.0f;
		float foam_factor_paint= 0.0f;
		if (TEST_CATEGORY_OPTION(foam, auto) || TEST_CATEGORY_OPTION(foam, both))
		{
			if (INTERPOLATORS.base_tex.z < 0)
				wave_choppiness_ratio= 0;

			foam_factor_auto= saturate(wave_choppiness_ratio - foam_cut)/saturate(1.0f - foam_cut);
			foam_factor_auto= pow(foam_factor_auto, max(foam_pow, 1.0f));
		}

		if (TEST_CATEGORY_OPTION(foam, paint) || TEST_CATEGORY_OPTION(foam, both))
		{
			foam_factor_paint= global_shape_from_texture.b;
		}

		// output factor
		if (TEST_CATEGORY_OPTION(foam, auto))
		{
			foam_factor= foam_factor_auto;
		}
		else if (TEST_CATEGORY_OPTION(foam, paint))
		{
			foam_factor= foam_factor_paint;
		}
		else if (TEST_CATEGORY_OPTION(foam, both))
		{
			foam_factor= max(foam_factor_auto, foam_factor_paint);
		}

		if (!TEST_CATEGORY_OPTION(foam, none))
		{
			// add ripple foam
			foam_factor= max(ripple_foam_factor, foam_factor);
			foam_factor*= foam_coefficient;						// this value is undefined unless foam != NONE

			foam_factor*= saturate(20 * one_over_camera_distance);

			[branch]
			if ( foam_factor > 0.002f )
			{
				// blend textures
				float4 foam= tex2D(foam_texture, transform_texcoord(INTERPOLATORS.texcoord.xy, foam_texture_xform));
				float4 foam_detail= tex2D(foam_texture_detail, transform_texcoord(INTERPOLATORS.texcoord.xy, foam_texture_detail_xform));
				foam_color.rgb= foam.rgb * foam_detail.rgb;
				foam_color.a= foam.a * foam_detail.a;		
				foam_factor= foam_color.w * foam_factor;
			}
		}
	}

	// compute diffuse by n dot l, really a hack!				// yeah yeah, this is basically just saying water_diffuse * normal.z
	float3 water_kd=		water_diffuse; 
	float3 sun_dir_ws=		float3(0.0, 0.0, 1.0);				//	sun direction up??
	//sun_dir_ws=			normalize(sun_dir_ws);
	float n_dot_l=			saturate(dot(sun_dir_ws, normal));	// == normal.z
	float3 color_diffuse=	water_kd * n_dot_l;					

	// compute reflection
	float3 color_reflection= 0;		//float3(0.1, 0.1, 0.1) * reflection_coefficient;
	if (TEST_CATEGORY_OPTION(reflection, none))
	{
		color_reflection= float3(0, 0, 0);
	}
	else
	{
		// calculate reflection direction
//		float3x3 tangent_frame_matrix= { INTERPOLATORS.tangent.xyz, INTERPOLATORS.binormal.xyz, INTERPOLATORS.normal.xyz };

//		float3 normal_reflect= mul(normalize(float3(slope_shading * normal_variation_tweak, 1.0f)), tangent_frame_matrix);	
//		normal_reflect= normalize(normal_reflect);	
	
//		float3 normal_reflect= normal;
//		float3 normal_reflect= lerp(normal, INTERPOLATORS.normal.xyz, normal_variation_tweak);		// NOTE: uses inverted normal variation tweak
//		normal_reflect.xy=	slope_shading * normal_variation_tweak;
//		normal_reflect.z=	saturate(dot(normal_reflect.xy, normal_reflect.xy));
//		normal_reflect.z=	sqrt(1 - normal_reflect.z);
		float3 normal_reflect= lerp(normal, float3(0.0f, 0.0f, 1.0f), 1.0f - normal_variation_tweak);	// NOTE: uses inverted normal variation tweak -- if we invert ourselves we can save this op
		
		float3 reflect_dir= reflect(-INTERPOLATORS.incident_ws.xyz, normal_reflect);
		reflect_dir.y*= -1.0;

		// sample environment map
		float4 environment_sample;
		if (TEST_CATEGORY_OPTION(reflection, static))
		{         
			environment_sample= texCUBE(environment_map, reflect_dir);
			environment_sample.rgb *= 256;		// static cubemap doesn't have exponential bias
		}
		else if (TEST_CATEGORY_OPTION(reflection, dynamic))
		{
			float4 reflection_0= texCUBE(dynamic_environment_map_0, reflect_dir);
//			float4 reflection_1= texCUBE(dynamic_environment_map_1, reflect_dir);
			environment_sample= reflection_0;//* dynamic_environment_blend.w;				//	reflection_1 * (1.0f-dynamic_environment_blend.w);
			environment_sample.rgb *= environment_sample.rgb * 4;
			environment_sample.a /= 4;
			// dynamnic cubempa has 2 exponent bias. so we need to restore the original value for the original math
		}

		// evualuate HDR color with considering of shadow
		float2 parts;
		parts.x= saturate(environment_sample.a - sunspot_cut);
		parts.y= min(environment_sample.a, sunspot_cut);

		float3 sun_light_rate= saturate(lightmap_intensity - shadow_intensity_mark);
		float sun_scale= dot(sun_light_rate, sun_light_rate);

		const float shadowed_alpha= parts.x*sun_scale + parts.y;
		color_reflection= 
			environment_sample.rgb * 
			shadowed_alpha * 
			reflection_coefficient;       
	}	

	// only apply lightmap_intensity on diffuse and reflection, watercolor of refrection has already considered
	color_diffuse*= lightmap_intensity;	
	foam_color.rgb*= lightmap_intensity;

	// add dynamic lighting
	[branch]
	if (!no_dynamic_lights)
	{
		float3 simple_light_diffuse_light; //= 0.0f;
		float3 simple_light_specular_light; //= 0.0f;
		
		calc_simple_lights_analytical(
			INTERPOLATORS.position_ws,
			normal,
			-INTERPOLATORS.incident_ws.xyz,
			20,
			simple_light_diffuse_light,
			simple_light_specular_light);

		color_diffuse		+= simple_light_diffuse_light * water_kd;
		color_reflection	+= simple_light_specular_light;
	}

	// computer fresnel and output color	
//	float3 fresnel_normal= normal * 2 * (0.5f - k_is_camera_underwater);		// -1 for underwater
	float3 fresnel_normal= k_is_camera_underwater ? -normal : normal;
	
	float fresnel= compute_fresnel(INTERPOLATORS.incident_ws.xyz, fresnel_normal, fresnel_coefficient, fresnel_dark_spot);
	//fresnel= saturate(fresnel*ripple_slope_length);		// apply interaction disturbance
	
	
	float4 output_color;	

	if (alpha_blend_output)
	{
		output_color=	color_refraction_blend;
		
		// reflection blends on top of refraction, with alpha == fresnel factor
		output_color.rgb=	output_color.rgb * (1.0f - fresnel) + color_reflection * fresnel;
		output_color.a *=	(1.0f - fresnel);
	
		// diffuse is a glow layer
		output_color.rgb += color_diffuse;
	
		if (!TEST_CATEGORY_OPTION(bankalpha, none))
		{
			// bank alpha blends towards background
			output_color.rgb *=		bank_alpha;
			output_color.a=			1.0f - (1.0f-output_color.a)*bank_alpha;
		}

		if (!TEST_CATEGORY_OPTION(foam, none))
		{
			// opaque blend foam on top
			output_color.rgb=	output_color.rgb * (1.0f - foam_factor) + foam_color.rgb * foam_factor;
			output_color.a *=	(1.0f - foam_factor);
		}

		output_color.a= 1.0f - output_color.a;
		// fog -- can we skip it for alpha-blend?
	}
	else
	{		
		output_color.rgb= lerp(color_refraction, color_reflection,  fresnel);
	
		// add diffuse
		output_color.rgb= output_color.rgb + color_diffuse; 

		// apply bank alpha
		if ( !TEST_CATEGORY_OPTION(bankalpha, none) )
		{
			output_color.rgb= lerp(color_refraction_bed, output_color.rgb, bank_alpha);
		}

		// apply foam
		if (!TEST_CATEGORY_OPTION(foam, none))
		{
			output_color.rgb= lerp(output_color.rgb, foam_color.rgb, foam_factor);
		}
	
		// apply under water fog
		[branch]
		if (k_is_camera_underwater)
		{
			float transparence= 0.5f * saturate(1.0f - compute_fog_factor(k_ps_underwater_murkiness, INTERPOLATORS.incident_ws.w));
			output_color.rgb= lerp(k_ps_underwater_fog_color, output_color.rgb, transparence);
		}
		output_color.a= 1.0f;
	}

	output_color.rgb *= g_exposure.r;

	//output_color= lightmap_intensity;
	//output_color= abs(INTERPOLATORS.base_tex);
	//output_color= abs(INTERPOLATORS.texcoord * 0.25);	
	//output_color= float3(slope_shading, 0.5f);
	//output_color= abs(INTERPOLATORS.normal);
	//output_color= INTERPOLATORS.position_ws.w;
		
	return convert_to_render_target(output_color, false, true);
}

#endif //PIXEL_SHADER


/* entry point calls */

#ifdef VERTEX_SHADER
s_water_interpolators water_dense_per_pixel_vs( s_vertex_type_water_shading IN )
{
	s_water_render_vertex vertex= get_tessellated_vertex( IN );
	return transform_vertex( vertex, false );
}


s_water_interpolators water_flat_per_pixel_vs( s_vertex_type_water_shading IN )
{
	s_water_render_vertex vertex= get_vertex( IN, false);
	return transform_vertex( vertex, false );
}

s_water_interpolators water_flat_per_vertex_vs( s_vertex_type_water_shading IN )
{
	s_water_render_vertex vertex= get_vertex( IN, true );
	return transform_vertex( vertex, true );
}

s_water_interpolators water_flat_blend_per_pixel_vs(s_vertex_type_water_shading IN)
{
	s_water_render_vertex vertex= get_vertex( IN, false );
	return transform_vertex( vertex, false );
}

s_water_interpolators water_flat_blend_per_vertex_vs(s_vertex_type_water_shading IN)
{
	s_water_render_vertex vertex= get_vertex( IN, true );
	return transform_vertex( vertex, true );
}

s_water_interpolators lightmap_debug_mode_vs( s_vertex_type_water_shading IN )
{
	s_water_render_vertex vertex= get_vertex( IN, false );
	return transform_vertex( vertex, false );
}



#endif //VERTEX_SHADER


#ifdef PIXEL_SHADER
accum_pixel water_dense_per_pixel_ps(s_water_interpolators INTERPOLATORS)
{
	return water_shading(INTERPOLATORS, false, false);
}

accum_pixel water_flat_per_pixel_ps(s_water_interpolators INTERPOLATORS)
{
	return water_shading(INTERPOLATORS, false, false);
}

accum_pixel water_flat_per_vertex_ps(s_water_interpolators INTERPOLATORS)
{
	return water_shading(INTERPOLATORS, true, false);
}

accum_pixel water_flat_blend_per_pixel_ps(s_water_interpolators INTERPOLATORS)
{
	return water_shading(INTERPOLATORS, false, true);
}

accum_pixel water_flat_blend_per_vertex_ps(s_water_interpolators INTERPOLATORS)
{
	return water_shading(INTERPOLATORS, true, true);
}

accum_pixel lightmap_debug_mode_ps(s_water_interpolators IN)
{   	
	float4 out_color;
	
	// setup tangent frame
	
	float3 ambient_only= 0.0f;
	float3 linear_only= 0.0f;
	float3 quadratic= 0.0f;

	out_color= display_debug_modes(
		IN.lm_tex,
		IN.normal,
		IN.texcoord,
		IN.tangent,
		IN.binormal,
		IN.normal,
		ambient_only,
		linear_only,
		quadratic);
		
	return convert_to_render_target(out_color, true, false);	
}

#endif //PIXEL_SHADER