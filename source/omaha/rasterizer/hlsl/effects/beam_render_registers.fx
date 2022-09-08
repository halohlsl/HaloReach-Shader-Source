#ifndef _BEAM_RENDER_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _BEAM_RENDER_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#include "effects\beam_property.fx"
#include "effects\beam_state_list.fx"
#include "effects\beam_strip.fx"
#include "effects\function_definition.fx"

CBUFFER_BEGIN(Beam)
	CBUFFER_CONST_ARRAY(Beam,	s_property,				g_all_properties, [_index_max],						k_beam_all_properties)
	CBUFFER_CONST_ARRAY(Beam,	s_function_definition,	g_all_functions, [_maximum_overall_function_count],	k_beam_all_functions)
	CBUFFER_CONST_ARRAY(Beam,	float4,					g_all_colors, [_maximum_overall_color_count],		k_beam_all_colors)
CBUFFER_END

CBUFFER_BEGIN(BeamState)
	CBUFFER_CONST(BeamState,	s_overall_state,		g_all_state,										k_beam_state_all_state)
CBUFFER_END

CBUFFER_BEGIN(BeamStrip)
	CBUFFER_CONST(BeamStrip,	s_strip,				g_strip,											k_beam_strip)
CBUFFER_END

#endif

#endif
