/*
WIND_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
3/29/2007 5:53:07 PM (davcook)

*/

#ifndef _WIND_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _WIND_REGISTERS_FX_
#endif

#if DX_VERSION == 9

VERTEX_CONSTANT(float4, wind_data, 246);
VERTEX_CONSTANT(float4, wind_data2, 247);


VERTEX_SAMPLER_CONSTANT(wind_texture, 3);			// vertex shader

#elif DX_VERSION == 11

CBUFFER_BEGIN(WindVS)
	CBUFFER_CONST(WindVS,	float4, 	wind_data,		k_vs_wind_data)
	CBUFFER_CONST(WindVS,	float4, 	wind_data2,		k_vs_wind_data2)
CBUFFER_END

VERTEX_TEXTURE_AND_SAMPLER(_2D,		wind_texture,		k_vs_wind_texture,		3)

#endif

#endif
