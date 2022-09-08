#ifndef _CONTRAIL_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _CONTRAIL_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#include "effects\raw_contrail_profile.fx"

CBUFFER_BEGIN(ContrailIndex)
	CBUFFER_CONST(ContrailIndex,	uint4,					contrail_index_range,								k_contrail_index_range)
CBUFFER_END

RW_STRUCTURED_BUFFER(cs_contrail_profile_state_buffer,		k_cs_contrail_profile_state_buffer,		s_raw_contrail_profile,		0)
STRUCTURED_BUFFER(vs_contrail_profile_state_buffer,			k_vs_contrail_profile_state_buffer,		s_raw_contrail_profile,		16)

#endif

#endif
