/*
CONTRAIL_UPDATE_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
12/5/2005 11:50:57 AM (davcook)

*/

#if DX_VERSION == 9

#include "effects\contrail_update_registers.h"

VERTEX_CONSTANT(float4, hidden_from_compiler, k_vs_contrail_update_hidden_from_compiler)	// the compiler will complain if these are literals
VERTEX_CONSTANT(float, delta_time, k_vs_contrail_update_delta_time)

#elif DX_VERSION == 11

#include "effects\contrail_update_state.fx"
#include "effects\particle_row_buffer.fx"

#ifndef DEFINED_CONTRAIL_ROW_CONSTANTS
#define DEFINED_CONTRAIL_ROW_CONSTANTS
static const uint k_contrail_row_count_bits = 4;
static const uint k_contrail_row_update_params_bits = 14;
static const uint k_contrail_row_const_params_bits = 14;
#endif

CBUFFER_BEGIN(ContrailUpdateVS)
	CBUFFER_CONST(ContrailUpdateVS,		float,		delta_time,					k_vs_contrail_update_delta_time)
CBUFFER_END

STRUCTURED_BUFFER(update_params_buffer,	k_cs_contrail_update_params_buffer,		s_contrail_system_update_params,	6)
STRUCTURED_BUFFER(const_params_buffer,	k_cs_contrail_const_params_buffer,		s_contrail_system_const_params,		7)

#ifndef DEFINE_CPP_CONSTANTS
static const uint k_contrail_row_shift = 4;
static const uint k_contrail_row_mask = 0xf;
static const uint k_contrail_update_params_shift = k_contrail_row_count_bits;
static const uint k_contrail_update_params_mask = (1 << k_contrail_row_update_params_bits) - 1;
static const uint k_contrail_const_params_shift = k_contrail_update_params_shift + k_contrail_row_update_params_bits;
static const uint k_contrail_const_params_mask = (1 << k_contrail_row_const_params_bits) - 1;

static uint g_update_params_index;
static uint g_const_params_index;

#define g_all_properties const_params_buffer[g_const_params_index].all_properties
#define g_all_functions const_params_buffer[g_const_params_index].all_functions
#define g_all_colors const_params_buffer[g_const_params_index].all_colors
#define g_all_state update_params_buffer[g_update_params_index].all_state
#endif

#define CS_CONTRAIL_UPDATE_THREADS 64

#endif
