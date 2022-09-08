#ifndef _HLSL_CONSTANT_PERSIST_FX_
#define _HLSL_CONSTANT_PERSIST_FX_

//NOTE: if you modify any of this, than you need to modify hlsl_constant_persist.h 

/*

// ###xwan $TODO merge this part to entry_point.fx, which handle all marco generation of different entries

// BEGIN: -------- setup marco of entry_points ----------
// refer to macro_entry_point_names in shader_compiler\shader_macros.h

#define BUILD_ENTRY_TYPE_NAME(entry_point_name) ENTRY_TYPE_##entry_point_name
#define ENTRY_TYPE_default							0		//"default",							// _entry_point_default
#define ENTRY_TYPE_albedo							1		//"albedo",								// _entry_point_albedo
#define ENTRY_TYPE_static_default					2		//"static_default",						// _entry_point_static_lighting_default,	// when there are no lightmaps at all on level (or artists don't want to see them)
#define ENTRY_TYPE_static_per_pixel					3		//"static_per_pixel",					// _entry_point_static_lighting_per_pixel,	
#define ENTRY_TYPE_static_per_vertex				4		//"static_per_vertex",					// _entry_point_static_lighting_per_vertex,
#define ENTRY_TYPE_static_sh						5		//"static_sh",							// _entry_point_static_lighting_sh,			// for dynamic objects that haven't had ldprt or prt simulation run on them (and lightmaps exist)
#define ENTRY_TYPE_static_prt_ambient				6		//"static_prt_ambient",					// _entry_point_static_lighting_prt_ambient,		
#define ENTRY_TYPE_static_prt_linear				7		//"static_prt_linear",					// _entry_point_static_lighting_prt_linear,	
#define ENTRY_TYPE_static_prt_quadratic				8		//"static_prt_quadratic",				// _entry_point_static_lighting_prt_quadratic,		
#define ENTRY_TYPE_single_pass_per_pixel			9		//"single_pass_per_pixel",				// _entry_point_single_pass_lighting_per_pixel,	
#define ENTRY_TYPE_single_pass_per_vertex			10		//"single_pass_per_vertex",				// _entry_point_single_pass_lighting_per_vertex,
#define ENTRY_TYPE_single_pass_single_probe			11		//"single_pass_single_probe",			// _entry_point_single_pass_lighting_single_probe, 
#define ENTRY_TYPE_single_pass_single_probe_ambient	12		//"single_pass_single_probe_ambient",	// _entry_point_single_pass_lighting_single_probe_ambient,		

#if (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_albedo)
	#define entry_point_albedo
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_default)
	#define	entry_point_static_default
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_per_pixel)
	#define	entry_point_static_per_pixel
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_per_vertex)
	#define	entry_point_static_per_vertex
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_sh)
	#define	entry_point_static_sh
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_ambient)
	#define	entry_point_static_prt_ambient
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_linear)
	#define	entry_point_static_prt_linear
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_quadratic) 	
	#define	entry_point_static_prt_quadratic
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_per_pixel)
	#define entry_point_single_pass_per_pixel
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_per_vertex)
	#define	entry_point_single_pass_per_vertex
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_single_probe)
	#define	entry_point_single_pass_single_probe
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_single_probe_ambient)
	#define	entry_point_single_pass_single_probe_ambient
#endif

#undef ENTRY_TYPE_default
#undef ENTRY_TYPE_albedo
#undef ENTRY_TYPE_static_default
#undef ENTRY_TYPE_static_per_pixel
#undef ENTRY_TYPE_static_per_vertex
#undef ENTRY_TYPE_static_sh
#undef ENTRY_TYPE_static_prt_ambient
#undef ENTRY_TYPE_static_prt_linear
#undef ENTRY_TYPE_static_prt_quadratic
#undef ENTRY_TYPE_single_pass_per_pixel
#undef ENTRY_TYPE_single_pass_per_vertex
#undef ENTRY_TYPE_single_pass_single_probe
#undef ENTRY_TYPE_single_pass_single_probe_ambient
#undef BUILD_ENTRY_TYPE_NAME

// END: -------- setup marco of entry_points ----------



#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);

sampler should_never_be_used_sampler;

// Shader constants which are off-limits (expected to persist throughout the frame)
#define k_register_viewproj_xform				c0
#define k_register_camera_forward				c4
#define k_register_camera_left					c5
#define k_register_camera_up					c6
#define k_register_camera_position				c7
// constants c8-c11 are unused, and have been removed from persist

#define k_ravi_constants_start					c240

#define k_register_camera_position_ps			c16

// 5 registers per simple light: [c18,c58) used on pc and [c18,c98) used on xenon

#define k_register_simple_light_count			c17
#define k_register_simple_light_start			c18
#ifdef pc
#define k_maximum_simple_light_count			8
#else
#define k_maximum_simple_light_count			16
#endif

VERTEX_CONSTANT(float4x4, View_Projection, k_register_viewproj_xform);		// WARNING:  View_Projection[0] is _NOT_ the same as k_register_viewproj_xform, HLSL treats the matrix as transposed
VERTEX_CONSTANT(float3, Camera_Forward, k_register_camera_forward);			// the position and orientation of the camera in world space
VERTEX_CONSTANT(float3, Camera_Left, k_register_camera_left);
VERTEX_CONSTANT(float3, Camera_Up, k_register_camera_up);
VERTEX_CONSTANT(float3, Camera_Position, k_register_camera_position);

VERTEX_CONSTANT(float4, v_analytical_light_direction, c228);
VERTEX_CONSTANT(float4, v_analytical_light_intensity, c230);
VERTEX_CONSTANT(float4, v_exposure, c232 );
VERTEX_CONSTANT(float4, v_alt_exposure, c239 );
#define V_ILLUM_SCALE (v_alt_exposure.r)
#define V_ILLUM_EXPOSURE (v_alt_exposure.g)

VERTEX_CONSTANT(float4, v_lightmap_compress_constant_0, c231);
VERTEX_CONSTANT(float4, v_atmosphere_constant_extra, c15);
VERTEX_CONSTANT(float4, v_atmosphere_constant_0, c233);					
VERTEX_CONSTANT(float4, v_atmosphere_constant_1, c234);					
VERTEX_CONSTANT(float4, v_atmosphere_constant_2, c235);					
VERTEX_CONSTANT(float4, v_atmosphere_constant_3, c236);					
VERTEX_CONSTANT(float4, v_atmosphere_constant_4, c237);					
VERTEX_CONSTANT(float4, v_atmosphere_constant_5, c238);					

VERTEX_CONSTANT(float4x4, Shadow_Projection, c240);					// used for dynamic light, to hold the light projection matrix
VERTEX_CONSTANT(float4, v_lighting_constant_0, c240);
VERTEX_CONSTANT(float4, v_lighting_constant_1, c241);
VERTEX_CONSTANT(float4, v_lighting_constant_2, c242);
VERTEX_CONSTANT(float4, v_lighting_constant_3, c243);

VERTEX_CONSTANT(float4, k_vs_wetness_constants, c244);				// x: width of wetness texture; y: offset of wetness texture; z: unused; w: probe wetness (notice, if -1 means no valid wetness texture)

// vertex constant c245 : unnused
// vertex constant c246 : unnused
// vertex constant c247 : unnused
// vertex constant c248 : unnused
// vertex constant c249 : unnused

PIXEL_CONSTANT(float4, g_exposure, c0 );							// exposure multiplier, HDR target multiplier, HDR alpha multiplier, LDR alpha multiplier		// ###ctchou $REVIEW could move HDR target multiplier to exponent bias and just set HDR alpha multiplier..
PIXEL_CONSTANT(float4, p_lighting_constant_0, c1);					// NOTE: these are also used for shadow_apply entry point (to hold the shadow projection matrix), as well as dynamic lights (to hold additional shadow info)
PIXEL_CONSTANT(float4, Shadow_Projection_z, c1);					//
PIXEL_CONSTANT(float4, p_lighting_constant_1, c2);
PIXEL_CONSTANT(float4, p_lighting_constant_2, c3);
PIXEL_CONSTANT(float4, p_lighting_constant_3, c4);
PIXEL_CONSTANT(float4, p_lighting_constant_4, c5);
PIXEL_CONSTANT(float4, p_dynamic_light_gel_xform, c5);				// overlaps lighting constant - they're unused in the expensive dynamic light pass
PIXEL_CONSTANT(float4, p_lighting_constant_5, c6);
PIXEL_CONSTANT(float4, p_lighting_constant_6, c7);
PIXEL_CONSTANT(float4, p_lighting_constant_7, c8);
PIXEL_CONSTANT(float4, p_lighting_constant_8, c9);
PIXEL_CONSTANT(float4, p_lighting_constant_9, c10);

#define p_vmf_lighting_constant_0 p_lighting_constant_0
#define p_vmf_lighting_constant_1 p_lighting_constant_1
#define p_vmf_lighting_constant_2 p_lighting_constant_2
#define p_vmf_lighting_constant_3 p_lighting_constant_3

PIXEL_CONSTANT(float4, g_alt_exposure, c12);						// self-illum exposure, unused, unused, unused
#define ILLUM_SCALE (g_alt_exposure.r)
#define ILLUM_EXPOSURE (g_alt_exposure.g)

// ###xwan moved from oneshot
PIXEL_CONSTANT(float2,  texture_size, c14);							// used for pixel-shader implemented bilinear, and albedo textures
PIXEL_CONSTANT(float4,  dynamic_environment_blend, c15);

// PIXEL_CONSTANT(float4, p_camera_view_direction_prescaled, c206);	// camera view direction, scaled by sqrt(depth scale) - used for antialiasing depth importance in object velocity calculations -- removed to pre-process
PIXEL_CONSTANT(float4, command_buffer_safe[4], c208);				// 4-block	208, 209, 210, 211
PIXEL_CONSTANT(float4, p_lightmap_compress_constant_0, c210);

PIXEL_CONSTANT(float3, depth_constants, c201);

#ifndef pc
PIXEL_CONSTANT(float4, p_tiling_vpos_offset, c108);
PIXEL_CONSTANT(float4, p_tiling_resolvetexture_xform, c109);
//PIXEL_CONSTANT(float4, p_tiling_reserved2,   c110);
//PIXEL_CONSTANT(float4, p_tiling_reserved3,   c111);
#endif
PIXEL_CONSTANT(float4, antialias_scalars, c110);					// 
PIXEL_CONSTANT(float4, object_velocity, c111);						// velocity of the current object, world space per object (approx)	###ctchou $TODO we could compute this in the vertex shader as a function of the bones...

PIXEL_CONSTANT(float4, p_render_debug_mode, c94);					// 92, 93, 94, 95

#ifdef pc
PIXEL_CONSTANT(float, p_shader_pc_specular_enabled, c95);				// first register after simple lights
PIXEL_CONSTANT(float, p_shader_pc_albedo_lighting, c96);
#endif // pc


// wetness constants
PIXEL_CONSTANT(float4, k_ps_rain_ripple_coefficients, c97);		// tex_scale, size_with_margin, splash_reflection_intensify, display_speed
PIXEL_CONSTANT(float4, k_ps_wetness_coefficients, c98);			// wetness, game_time(second), cubemap blending, rain intensity

#ifdef pc

PIXEL_CONSTANT(float, simple_light_count, k_register_simple_light_count);
PIXEL_CONSTANT(float4, simple_lights[k_maximum_simple_light_count][5], k_register_simple_light_start); 
#define dynamic_lights_use_array_notation 1

#else // xenon

PIXEL_CONSTANT(int, simple_light_count_int, i0);
PIXEL_CONSTANT(float, simple_light_count_float, k_register_simple_light_count);

#ifdef xdk_2907
// stupid unoptimized code can't handle loops apparently - requires floating point light count
#define simple_light_count simple_light_count_float
PIXEL_CONSTANT(float4, simple_lights[k_maximum_simple_light_count][5], k_register_simple_light_start); 
#define dynamic_lights_use_array_notation 1
#else
#define simple_light_count simple_light_count_int
PIXEL_CONSTANT(float4, simple_lights[k_maximum_simple_light_count * 5], k_register_simple_light_start); 
#endif

#endif // xenon

PIXEL_CONSTANT(float3, Camera_Position_PS, k_register_camera_position_ps);

bool always_true : register(b0);
#ifdef pc
	#define actually_calc_albedo true	// no bool constants in pixel shader
	//	###xwan	constants for light map dxt5 compression, reservated comstants from 60 to 79
	#define p_lightmap_compress_constant_using_dxt true	// lighting calcs albedo instead of sampling it 
#else
	bool actually_calc_albedo : register(b0);	// lighting calcs albedo instead of sampling it 
	//	###xwan	constants for light map dxt5 compression, reservated comstants from 60 to 79
	bool p_lightmap_compress_constant_using_dxt : register(b10);	// lighting calcs albedo instead of sampling it 
#endif 


//PIXEL_CONSTANT(bool, LDR_gamma2, b14);		// ###ctchou $TODO $PERF remove these when we settle on a render target format
//PIXEL_CONSTANT(bool, HDR_gamma2, b15);



// ---- boolean constants ----
BOOL_CONSTANT(k_boolean_enable_wet_effect, 121);
BOOL_CONSTANT(k_boolean_enable_imposter_capture, 122);


// ---- vertex shader samplers ----
#ifndef pc
	VERTEX_CONSTANT  (sampler, lightprobe_dir_and_bandwidth_vs, s0);
	VERTEX_CONSTANT  (sampler, lightprobe_hdr_color_vs, s2);

	#ifdef _xenon_tessellation_post_pass_vs
		VERTEX_CONSTANT (sampler, sampler_shader_cache_stream, s3);
	#else
	    ///  DESC: 15 Dec 2008   12:4 BUNGIE\yaohhu :
	    ///     I have to connect these conditions into one line so shader compiler works in PIX 
		#if defined(entry_point_static_per_pixel) || defined(entry_point_static_per_vertex) || defined(entry_point_static_sh) || defined(entry_point_static_prt_ambient) || defined(entry_point_static_prt_linear) || defined(entry_point_static_prt_quadratic)

			#define USE_PER_VERTEX_WETNESS_TEXTURE
			VERTEX_CONSTANT (sampler, k_vs_sampler_per_vertex_wetness, s3);	

		#endif
	#endif
#endif //xenon


// ---- pixel shader samplers ----
// do not allow any collisions by explicitly declaring samplers greater than 10 elsewhere!!!
//STATIC LIGHTING

#ifndef SINGLE_PASS_LIGHTING
PIXEL_CONSTANT (sampler, albedo_texture, s10);
PIXEL_CONSTANT (sampler, normal_texture, s11);
#endif //SINGLE_PASS_LIGHTING

// albedo shader or vertex shahder, no wet
#if defined(entry_point_albedo) || defined(VERTEX_SHADER) || defined(pc)
	#define NO_WETNESS_EFFECT
#endif

#ifndef pc
	#ifndef NO_WETNESS_EFFECT
		PIXEL_CONSTANT (sampler, k_ps_sampler_wet_cubemap_0, s16);
		PIXEL_CONSTANT (sampler, k_ps_sampler_wet_cubemap_1, s17);		
		PIXEL_CONSTANT (sampler, k_ps_sampler_wet_rain_ripple, s18);
	#endif //NO_WETNESS_EFFECT		

	PIXEL_CONSTANT (sampler, lightprobe_dir_and_bandwidth_ps, s12);
	PIXEL_CONSTANT (sampler, lightprobe_hdr_color_ps, s13);
	PIXEL_CONSTANT (sampler, flip_mask, s14);

	#ifdef entry_point_albedo
		#define shadow_mask_texture should_never_be_used_sampler
	#else
		PIXEL_CONSTANT (sampler, shadow_mask_texture, s15);
	#endif //entry_point_albedo

#endif //!pc


//WATER, ACTIVE CAMO
PIXEL_CONSTANT (sampler, scene_ldr_texture, s10);

//WATER, PARTICLES 
PIXEL_CONSTANT (sampler, depth_buffer, s11);
*/

#endif //ifndef _HLSL_CONSTANT_PERSIST_FX_

