#ifndef _LIGHT_VOLUME_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _LIGHT_VOLUME_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#include "effects\raw_light_volume_profile.fx"

CBUFFER_BEGIN(LightVolumeIndex)
	CBUFFER_CONST(LightVolumeIndex,		uint4,					light_volume_index_range,							k_light_volume_index_range)
CBUFFER_END

RW_STRUCTURED_BUFFER(cs_light_volume_profile_state_buffer,		k_cs_light_volume_profile_state_buffer,		s_raw_light_volume_profile,		0)
STRUCTURED_BUFFER(vs_light_volume_profile_state_buffer,			k_vs_light_volume_profile_state_buffer,		s_raw_light_volume_profile,		16)

#define CS_LIGHT_VOLUME_UPDATE_THREADS 64

#endif

#endif
