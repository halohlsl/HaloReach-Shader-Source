/*
WIND.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
3/29/2007 5:52:31 PM (davcook)

*/

#if !defined(pc) || (DX_VERSION == 11)

#include "effects\wind_registers.fx"

float2 sample_wind(float2 position)
{
	// apply wind
	float2 texc= position.xy * wind_data.z + wind_data.xy;			// calculate wind texcoord
	float4 wind_vector;
#ifdef xenon
	asm {
		tfetch2D wind_vector, texc, wind_texture, MinFilter=linear, MagFilter=linear, UseComputedLOD=false, UseRegisterGradients=false
	};
#elif DX_VERSION == 11
	wind_vector= wind_texture.t.SampleLevel(wind_texture.s, texc, 0);
#endif
	wind_vector.xy= wind_vector.xy * wind_data2.z + wind_data2.xy;			// scale motion and add in bend

	return wind_vector;
}

#endif