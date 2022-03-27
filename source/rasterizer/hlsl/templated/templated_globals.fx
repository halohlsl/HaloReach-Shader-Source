#ifndef __TEMPLATED_GLOBALS_FX
#define __TEMPLATED_GLOBALS_FX

#include "hlsl_entry_points.fx"
#include "shared\blend.fx"


// figure out what global constant scopes are active for this entry_point / blend_mode / platform

#define SCOPE_MESH_DEFAULT
#if defined(entry_point_lighting)
	#define SCOPE_LIGHTING
#endif // entry_point_lighting

#if defined(entry_point_lighting)
	#if defined(BLEND_MODE_OFF)
		#define SCOPE_LIGHTING_OPAQUE
	#else
		#define SCOPE_TRANSPARENTS
		#define SINGLE_PASS_LIGHTING
	#endif
#else
	#define SINGLE_PASS_LIGHTING
	
	#if !defined(BLEND_MODE_OFF)
		#define SCOPE_TRANSPARENTS
	#endif
	
#endif // BLEND_MODE_OFF

#ifdef _xenon_tessellation_post_pass_vs
	#define SCOPE_TESSELATION
#else
	#if defined(entry_point_lighting) && defined(BLEND_MODE_OFF) && defined(xenon) && !defined(NO_WETNESS_EFFECT)
		#define SCOPE_WETNESS
		#define USE_PER_VERTEX_WETNESS_TEXTURE
	#endif
#endif

#ifndef SCOPE_WETNESS
	#define NO_WETNESS_EFFECT
#endif // SCOPE_WETNESS

#ifdef USE_PER_VERTEX_WETNESS_TEXTURE
	#define WETNESS_VERTEX_INDEX vertex_index
#else
	#define WETNESS_VERTEX_INDEX 0
#endif

#include "hlsl_constant_globals.fx"



#endif // __TEMPLATED_GLOBALS_FX
