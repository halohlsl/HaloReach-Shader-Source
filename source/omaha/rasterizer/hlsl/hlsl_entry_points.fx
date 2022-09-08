#ifndef __HLSL_ENTRY_POINTS_FX
#define __HLSL_ENTRY_POINTS_FX


/* BEGIN: -------- setup marco of entry_points ---------- */
// refer to macro_entry_point_names in shader_compiler\shader_macros.h

#define BUILD_ENTRY_TYPE_NAME(entry_point_name) ENTRY_TYPE_##entry_point_name
#define ENTRY_TYPE_no_entry_point					0
#define ENTRY_TYPE_default							1		//"default",							// _entry_point_default
#define ENTRY_TYPE_albedo							2		//"albedo",								// _entry_point_albedo
#define ENTRY_TYPE_static_default					3		//"static_default",						// _entry_point_static_lighting_default,	// when there are no lightmaps at all on level (or artists don't want to see them)
#define ENTRY_TYPE_static_per_pixel					4		//"static_per_pixel",					// _entry_point_static_lighting_per_pixel,
#define ENTRY_TYPE_static_per_vertex				5		//"static_per_vertex",					// _entry_point_static_lighting_per_vertex,
#define ENTRY_TYPE_static_sh						6		//"static_sh",							// _entry_point_static_lighting_sh,			// for dynamic objects that haven't had ldprt or prt simulation run on them (and lightmaps exist)
#define ENTRY_TYPE_static_prt_ambient				7		//"static_prt_ambient",					// _entry_point_static_lighting_prt_ambient,
#define ENTRY_TYPE_static_prt_linear				8		//"static_prt_linear",					// _entry_point_static_lighting_prt_linear,
#define ENTRY_TYPE_static_prt_quadratic				9		//"static_prt_quadratic",				// _entry_point_static_lighting_prt_quadratic,
#define ENTRY_TYPE_dynamic_light					10		//"dynamic_light",						// _entry_point_dynamic_lighting
#define ENTRY_TYPE_shadow_generate					11		//"shadow_generate",					// _entry_point_shadow_generate
#define ENTRY_TYPE_shadow_apply						12		//"shadow_apply",						// _entry_point_shadow_apply
#define ENTRY_TYPE_active_camo						13		//"active_camo",						// _entry_point_active_camo
#define ENTRY_TYPE_lightmap_debug_mode				14		//"lightmap_debug_mode",				// _entry_point_lightmap_debug_mode
#define ENTRY_TYPE_static_per_vertex_color			15		//"static_per_vertex_color",			// _entry_point_vertex_color_lighting
#define ENTRY_TYPE_water_tessellation				16		//"water_tessellation",					// _entry_point_water_tesselletion
#define ENTRY_TYPE_water_shading					17		//"water_shading",						// _entry_point_water_shading
#define ENTRY_TYPE_dynamic_light_cinematic			18		//"dynamic_light_cinematic",			// _entry_point_dynamic_lighting_cinematic
#define ENTRY_TYPE_single_pass_per_pixel			19		//"single_pass_per_pixel",				// _entry_point_single_pass_lighting_per_pixel,
#define ENTRY_TYPE_single_pass_per_vertex			20		//"single_pass_per_vertex",				// _entry_point_single_pass_lighting_per_vertex,
#define ENTRY_TYPE_single_pass_single_probe			21		//"single_pass_single_probe",			// _entry_point_single_pass_lighting_single_probe,
#define ENTRY_TYPE_single_pass_single_probe_ambient	22		//"single_pass_single_probe_ambient",	// _entry_point_single_pass_lighting_single_probe_ambient,
#define ENTRY_TYPE_imposter_static_sh						23		//"imposter_static_sh",			// _entry_point_single_pass_lighting_single_probe,
#define ENTRY_TYPE_imposter_static_prt_ambient				24		//"imposter_static_prt_ambient",	// _entry_point_single_pass_lighting_single_probe_ambient,
#define ENTRY_TYPE_dynamic_light_hq_shadows			25
#define ENTRY_TYPE_dynamic_light_cinematic_hq_shadows			26

#if (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_no_entry_point)
	#error
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_albedo)
	#define entry_point_albedo
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_default)
	#define	entry_point_static_default
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_per_pixel)
	#define	entry_point_static_per_pixel
	#define entry_point_lighting
	#define must_be_environment
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_per_vertex)
	#define	entry_point_static_per_vertex
	#define entry_point_lighting
	#define must_be_environment
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_sh)
	#define	entry_point_static_sh
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_ambient)
	#define	entry_point_static_prt_ambient
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_linear)
	#define	entry_point_static_prt_linear
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_static_prt_quadratic)
	#define	entry_point_static_prt_quadratic
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_per_pixel)
	#define entry_point_single_pass_per_pixel
	#define entry_point_lighting
	#define must_be_environment
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_per_vertex)
	#define	entry_point_single_pass_per_vertex
	#define entry_point_lighting
	#define must_be_environment
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_single_probe)
	#define	entry_point_single_pass_single_probe
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_single_pass_single_probe_ambient)
	#define	entry_point_single_pass_single_probe_ambient
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_dynamic_light)
	#define entry_point_dynamic_light
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_dynamic_light_cinematic)
	#define entry_point_dynamic_light_cinematic
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_imposter_static_sh)
	#define entry_point_imposter_static_sh
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_imposter_static_prt_ambient)
	#define entry_point_imposter_static_prt_ambient
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_dynamic_light_hq_shadows)
	#define entry_point_dynamic_light_hq_shadows
	#define entry_point_lighting
#elif (BUILD_ENTRY_TYPE_NAME(entry_point) == ENTRY_TYPE_dynamic_light_cinematic_hq_shadows)
	#define entry_point_dynamic_light_cinematic_hq_shadows
	#define entry_point_lighting
#else
	// other entry point -- shadow generate, or something...
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


#endif // __HLSL_ENTRY_POINTS_FX