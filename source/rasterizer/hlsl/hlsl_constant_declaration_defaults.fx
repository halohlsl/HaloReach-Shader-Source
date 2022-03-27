
// setup defaults for all macros that haven't been defined yet
// (and remember that they are defaults so we can clear them later)
// we also append the HLSL register bank to the shader (i.e. register bank 'c' for float register c100)

#ifndef SHADER_CONSTANT
#define SHADER_CONSTANT(a,b,c,d,e,f,g,h,i)
#define SHADER_CONSTANT_DEFAULT
#endif // SHADER_CONSTANT

#ifndef VERTEX_CONSTANT
#define VERTEX_CONSTANT(a,b,c,d,e,f,g,h) SHADER_CONSTANT(a,b,c,d,e,f,g,VERTEX, h)
#define VERTEX_CONSTANT_DEFAULT
#endif // VERTEX_CONSTANT

#ifndef PIXEL_CONSTANT
#define PIXEL_CONSTANT(a,b,c,d,e,f,g,h) SHADER_CONSTANT(a,b,c,d,e,f,g,PIXEL, h)
#define PIXEL_CONSTANT_DEFAULT
#endif // PIXEL_CONSTANT


#ifndef VERTEX_FLOAT
#define VERTEX_FLOAT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) VERTEX_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, c, command_buffer_option)
#define VERTEX_FLOAT_DEFAULT
#endif // VERTEX_FLOAT

#ifndef VERTEX_INT
#define VERTEX_INT(		hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) VERTEX_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, i, command_buffer_option)
#define VERTEX_INT_DEFAULT
#endif // VERTEX_INT

#ifndef VERTEX_BOOL
#define VERTEX_BOOL(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) VERTEX_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, b, command_buffer_option)
#define VERTEX_BOOL_DEFAULT
#endif // VERTEX_BOOL

#ifndef VERTEX_SAMPLER
#define VERTEX_SAMPLER(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) VERTEX_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, s, command_buffer_option)
#define VERTEX_SAMPLER_DEFAULT
#endif // VERTEX_SAMPLER

#ifndef VERTEX_FLOAT_FREE_FOR_SHADERS
#define VERTEX_FLOAT_FREE_FOR_SHADERS(a, b)
#define VERTEX_FLOAT_FREE_FOR_SHADERS_DEFAULT
#endif // VERTEX_FLOAT_FREE_FOR_SHADERS


#ifndef PIXEL_FLOAT
#define PIXEL_FLOAT(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) PIXEL_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, c, command_buffer_option)
#define PIXEL_FLOAT_DEFAULT
#endif // PIXEL_FLOAT

#ifndef PIXEL_INT
#define PIXEL_INT(		hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) PIXEL_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, i, command_buffer_option)
#define PIXEL_INT_DEFAULT
#endif // PIXEL_INT

#ifndef PIXEL_BOOL
#define PIXEL_BOOL(		hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) PIXEL_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, b, command_buffer_option)
#define PIXEL_BOOL_DEFAULT
#endif // PIXEL_BOOL

#ifndef PIXEL_SAMPLER
#define PIXEL_SAMPLER(	hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, command_buffer_option) PIXEL_CONSTANT(hlsl_type,	hlsl_name,	code_name,	register_start,	register_count,	scope, s, command_buffer_option)
#define PIXEL_SAMPLER_DEFAULT
#endif // PIXEL_SAMPLER

#ifndef PIXEL_FLOAT_FREE_FOR_SHADERS
#define PIXEL_FLOAT_FREE_FOR_SHADERS(a, b)
#define PIXEL_FLOAT_FREE_FOR_SHADERS_DEFAULT
#endif // PIXEL_FLOAT_FREE_FOR_SHADERS


// setup platform specific macros

#if defined(pc) || defined(PC) || defined(DEFINE_XENON_AND_PC_CONSTANTS)

#define PC_VERTEX_FLOAT(a,b,c,d,e,f,g)	VERTEX_FLOAT(a,b,c,d,e,f,g)
#define PC_VERTEX_INT(a,b,c,d,e,f,g)		VERTEX_INT(a,b,c,d,e,f,g)
#define PC_VERTEX_BOOL(a,b,c,d,e,f,g)		VERTEX_BOOL(a,b,c,d,e,f,g)
#define PC_VERTEX_SAMPLER(a,b,c,d,e,f,g)	VERTEX_SAMPLER(a,b,c,d,e,f,g)
#define PC_PIXEL_FLOAT(a,b,c,d,e,f,g)		PIXEL_FLOAT(a,b,c,d,e,f,g)
#define PC_PIXEL_INT(a,b,c,d,e,f,g)		PIXEL_INT(a,b,c,d,e,f,g)
#define PC_PIXEL_BOOL(a,b,c,d,e,f,g)		PIXEL_BOOL(a,b,c,d,e,f,g)
#define PC_PIXEL_SAMPLER(a,b,c,d,e,f,g)	PIXEL_SAMPLER(a,b,c,d,e,f,g)

#else

#define PC_VERTEX_FLOAT(a,b,c,d,e,f,g)
#define PC_VERTEX_INT(a,b,c,d,e,f,g)
#define PC_VERTEX_BOOL(a,b,c,d,e,f,g)
#define PC_VERTEX_SAMPLER(a,b,c,d,e,f,g)
#define PC_PIXEL_FLOAT(a,b,c,d,e,f,g)
#define PC_PIXEL_INT(a,b,c,d,e,f,g)
#define PC_PIXEL_BOOL(a,b,c,d,e,f,g)
#define PC_PIXEL_SAMPLER(a,b,c,d,e,f,g)

#endif // PC


#if defined(xenon) || defined(XENON) || defined(DEFINE_XENON_AND_PC_CONSTANTS)

#define XE_VERTEX_FLOAT(a,b,c,d,e,f,g)	VERTEX_FLOAT(a,b,c,d,e,f,g)
#define XE_VERTEX_INT(a,b,c,d,e,f,g)		VERTEX_INT(a,b,c,d,e,f,g)
#define XE_VERTEX_BOOL(a,b,c,d,e,f,g)		VERTEX_BOOL(a,b,c,d,e,f,g)
#define XE_VERTEX_SAMPLER(a,b,c,d,e,f,g)	VERTEX_SAMPLER(a,b,c,d,e,f,g)
#define XE_PIXEL_FLOAT(a,b,c,d,e,f,g)		PIXEL_FLOAT(a,b,c,d,e,f,g)
#define XE_PIXEL_INT(a,b,c,d,e,f,g)		PIXEL_INT(a,b,c,d,e,f,g)
#define XE_PIXEL_BOOL(a,b,c,d,e,f,g)		PIXEL_BOOL(a,b,c,d,e,f,g)
#define XE_PIXEL_SAMPLER(a,b,c,d,e,f,g)	PIXEL_SAMPLER(a,b,c,d,e,f,g)

#else

#define XE_VERTEX_FLOAT(a,b,c,d,e,f,g)
#define XE_VERTEX_INT(a,b,c,d,e,f,g)
#define XE_VERTEX_BOOL(a,b,c,d,e,f,g)
#define XE_VERTEX_SAMPLER(a,b,c,d,e,f,g)
#define XE_PIXEL_FLOAT(a,b,c,d,e,f,g)
#define XE_PIXEL_INT(a,b,c,d,e,f,g)
#define XE_PIXEL_BOOL(a,b,c,d,e,f,g)
#define XE_PIXEL_SAMPLER(a,b,c,d,e,f,g)

#endif // XENON