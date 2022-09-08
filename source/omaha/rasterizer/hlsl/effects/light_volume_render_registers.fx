#ifndef _LIGHT_VOLUME_RENDER_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _LIGHT_VOLUME_RENDER_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#define LIGHT_VOLUME_RENDER

#include "effects\light_volume_state.fx"
#include "effects\light_volume_strip.fx"
#include "effects\function_definition.fx"
#include "effects\raw_light_volume_profile.fx"

CBUFFER_BEGIN(LightVolumeState)
	CBUFFER_CONST(LightVolumeState,		s_overall_state,		g_all_state,										k_light_volume_state_all_state)
CBUFFER_END

CBUFFER_BEGIN(LightVolumeStrip)
	CBUFFER_CONST(LightVolumeStrip,		s_strip,				g_strip,											k_light_volume_strip)
CBUFFER_END

#endif

#endif
