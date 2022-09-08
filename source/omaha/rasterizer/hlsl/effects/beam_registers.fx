#ifndef _BEAM_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _BEAM_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#include "effects\raw_beam_profile_state.fx"

CBUFFER_BEGIN(BeamIndex)
	CBUFFER_CONST(BeamIndex,	uint4,					beam_index_range,									k_beam_index_range)
CBUFFER_END

RW_STRUCTURED_BUFFER(cs_beam_profile_state_buffer,		k_cs_beam_profile_state_buffer,		s_raw_beam_profile_state,		0)
STRUCTURED_BUFFER(vs_beam_profile_state_buffer,			k_vs_beam_profile_state_buffer,		s_raw_beam_profile_state,		16)

#define CS_BEAM_UPDATE_THREADS 64

#endif

#endif
