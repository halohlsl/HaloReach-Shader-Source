#ifndef _POSTPROCESS_FX_
#define _POSTPROCESS_FX_

#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif

#define CONSTANT_NAME(n) c##n
#include "postprocess\postprocess_registers.h"

PIXEL_CONSTANT(float4, g_exposure, c0 );
PIXEL_CONSTANT(float4, g_alt_exposure, c11);			// ###m-jowaters $TODO - this should always match g_alt_exposure in hlsl_constant_global_list.fx!

/*
PIXEL_CONSTANT(bool, LDR_gamma2, b14);					// ###ctchou $TODO $PERF remove these when we settle on a render target format
PIXEL_CONSTANT(bool, HDR_gamma2, b15);
*/

#ifndef USE_CUSTOM_POSTPROCESS_CONSTANTS

PIXEL_CONSTANT( float4, pixel_size, POSTPROCESS_PIXELSIZE_PIXEL_CONSTANT );
PIXEL_CONSTANT( float4, scale,		POSTPROCESS_DEFAULT_PIXEL_CONSTANT );


#include "shared\texture.fx"

#endif

#include "shared\render_target.fx"

#define ILLUM_SCALE (g_alt_exposure.r)
#define ILLUM_EXPOSURE (g_alt_exposure.g)


struct screen_output
{
	float4 position		:POSITION;
	float2 texcoord		:TEXCOORD0;
#ifdef POSTPROCESS_COLOR				// ###ctchou $TODO fix shader patching?
	float4 color		:TEXCOORD1;
#endif // POSTPROCESS_COLOR
};

#ifndef POSTPROCESS_USE_CUSTOM_VERTEX_SHADER

screen_output default_vs(vertex_type IN)
{
	screen_output OUT;
	OUT.texcoord=		IN.texcoord;
	OUT.position.xy=	IN.position;
	OUT.position.zw=	1.0f;
#ifdef POSTPROCESS_COLOR	
	OUT.color=			IN.color;
#endif // POSTPROCESS_COLOR
	return OUT;
}

#endif



#endif //ifndef _POSTPROCESS_FX_
