//
//  global HLSL scopes
//
//


//
//  SCOPE global_render
//						always active
//						can not be overwritten by any other values
//						not recorded in command buffers -- so try and pack them into blocks of 4!
//
#define SCOPE_global_render(			hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)


//
//  SCOPE mesh_default
//						active when using render_mesh() -- any shader that uses render_mesh is in this scope		(used to be hlsl_constant_oneshot.h)
//						can be overwritten when we are not using default mesh rendering
//						not recorded in command buffers -- pack them into blocks of 4!
//
#if defined(SCOPE_MESH_DEFAULT)
	#define SCOPE_mesh_default(			hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_mesh_default(			hlsl_type, hlsl_name, hlsl_register, stage)	
#endif


//
//  SCOPE mesh_skinning
//						same as mesh_default, except for particle rendering
//						particles use this scope to inherit the mesh_default scope, but turn off the skinning nodes
//						can be overwritten when we are not using default mesh rendering
//
#if defined(SCOPE_MESH_DEFAULT) && !defined(IGNORE_SKINNING_NODES)
	#define SCOPE_mesh_skinning(	hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_mesh_skinning(	hlsl_type, hlsl_name, hlsl_register, stage)
#endif


//
//  SCOPE lighting
//						active during lighting passes (static_lighting AND transparents)
//
#if defined(SCOPE_LIGHTING)
	#define SCOPE_lighting(			hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_lighting(			hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name
#endif


//
//  SCOPE lighting_opaque
//						active during lighting (opaque lit shaders only -- includes static_lighting shaders and dynamic_light (rerender) shaders)
//
#if defined(SCOPE_LIGHTING_OPAQUE)
	#define SCOPE_lighting_opaque(	hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_lighting_opaque(	hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name
#endif


//
//  SCOPE transparents
//						active during transparent rendering
//
#if defined(SCOPE_TRANSPARENTS)
	#define SCOPE_transparents(	hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_transparents(	hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name
#endif


//
//	SCOPE tesselation
//						active when using tesselation
//
#if defined(SCOPE_TESSELATION)
	#define SCOPE_tesselation(		hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_tesselation(		hlsl_type, hlsl_name, hlsl_register, stage)
#endif


//
//	SCOPE wetness ->	lighting, but not disabled because of transparency or other reasons  (###ctchou $TODO this really shouldn't be in globals I think...)
//
#if defined(SCOPE_LIGHTING) && !defined(NO_WETNESS_EFFECT)
	#define SCOPE_wetness(			hlsl_type, hlsl_name, hlsl_register, stage)		hlsl_type hlsl_name	stage##_REGISTER(hlsl_register)
#else
	#define SCOPE_wetness(			hlsl_type, hlsl_name, hlsl_register, stage)
#endif
