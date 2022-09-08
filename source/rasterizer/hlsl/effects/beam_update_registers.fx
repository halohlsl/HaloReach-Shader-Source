#ifndef _BEAM_UPDATE_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _BEAM_UPDATE_REGISTERS_FX_
#endif

#if DX_VERSION == 11

#include "effects\beam_update_state.fx"
#include "effects\particle_row_buffer.fx"

#ifndef DEFINED_BEAM_ROW_CONSTANTS
#define DEFINED_BEAM_ROW_CONSTANTS
static const uint k_beam_row_count_bits = 4;
static const uint k_beam_row_update_params_bits = 14;
static const uint k_beam_row_const_params_bits = 14;
#endif

STRUCTURED_BUFFER(update_params_buffer,		k_cs_beam_update_params_buffer, 	s_beam_system_update_params,	5)
STRUCTURED_BUFFER(const_params_buffer,		k_cs_beam_const_params_buffer, 		s_beam_system_const_params,		6)

#ifndef DEFINE_CPP_CONSTANTS
static const uint k_beam_row_shift = 4;
static const uint k_beam_row_mask = 0xf;
static const uint k_beam_update_params_shift = k_beam_row_count_bits;
static const uint k_beam_update_params_mask = (1 << k_beam_row_update_params_bits) - 1;
static const uint k_beam_const_params_shift = k_beam_update_params_shift + k_beam_row_update_params_bits;
static const uint k_beam_const_params_mask = (1 << k_beam_row_const_params_bits) - 1;

static uint g_update_params_index;
static uint g_const_params_index;

#define g_all_properties const_params_buffer[g_const_params_index].all_properties
#define g_all_functions const_params_buffer[g_const_params_index].all_functions
#define g_all_colors const_params_buffer[g_const_params_index].all_colors
#define g_all_state update_params_buffer[g_update_params_index].all_state
#endif

#endif

#endif
