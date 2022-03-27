

// Only assign registers to constants in the currently compiling shader stage (pixel/vertex)
#if defined(VERTEX_SHADER)
	#define VERTEX_REGISTER(hlsl_register)	: register(hlsl_register)
	#define PIXEL_REGISTER(hlsl_register)
#else	
	#define VERTEX_REGISTER(hlsl_register)
	#define PIXEL_REGISTER(hlsl_register)	: register(hlsl_register)	
#endif

