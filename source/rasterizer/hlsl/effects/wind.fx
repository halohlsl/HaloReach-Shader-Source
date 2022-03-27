/*
WIND.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
3/29/2007 5:52:31 PM (davcook)
	
*/

#ifndef pc

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define VERTEX_SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#include "effects\wind_registers.fx"
#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT


float2 sample_wind(float2 position)
{
	// apply wind
	float2 texc= position.xy * wind_data.z + wind_data.xy;			// calculate wind texcoord
	float4 wind_vector;
	asm {
		tfetch2D wind_vector, texc, wind_texture, MinFilter=linear, MagFilter=linear, UseComputedLOD=false, UseRegisterGradients=false
	};
	wind_vector.xy= wind_vector.xy * wind_data2.z + wind_data2.xy;			// scale motion and add in bend
	
	return wind_vector;
}

#endif