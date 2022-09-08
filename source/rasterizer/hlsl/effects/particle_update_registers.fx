/*
PARTICLE_UPDATE_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
12/5/2005 11:50:57 AM (davcook)

*/

#if DX_VERSION == 9

#include "effects\particle_update_registers.h"

VERTEX_CONSTANT(float, delta_time, k_vs_particle_update_delta_time)
VERTEX_CONSTANT(float4, hidden_from_compiler, k_vs_particle_update_hidden_from_compiler)	// the compiler will complain if these are literals
VERTEX_CONSTANT(float4x3, tile_to_world, k_vs_particle_update_tile_to_world)	//= {float3x3(Camera_Forward, Camera_Left, Camera_Up) * tile_size, Camera_Position};
VERTEX_CONSTANT(float4x3, world_to_tile, k_vs_particle_update_world_to_tile)	//= {transpose(float3x3(Camera_Forward, Camera_Left, Camera_Up) * inverse_tile_size), -Camera_Position};
VERTEX_CONSTANT(float4x3, occlusion_to_world, k_vs_particle_update_occlusion_to_world)
VERTEX_CONSTANT(float4x3, world_to_occlusion, k_vs_particle_update_world_to_occlusion)
VERTEX_CONSTANT(float4, turbulence_xform, k_vs_particle_update_turbulence_xform)
BOOL_CONSTANT(tiled, k_vs_particle_update_tiled)
// BOOL_CONSTANT(collision, 21)						// removed (leaving here for reference in case we want to eventually use the new weather occlusion system)
BOOL_CONSTANT(turbulence, k_vs_particle_update_turbulence)

#elif DX_VERSION == 11

#include "effects\particle_property.fx"
#include "effects\function_definition.fx"
#include "effects\particle_state_list.fx"
#include "effects\particle_update_state.fx"
#include "effects\particle_row_buffer.fx"

#ifndef DEFINED_PARTICLE_ROW_CONSTANTS
#define DEFINED_PARTICLE_ROW_CONSTANTS
static const uint k_particle_row_count_bits = 4;
static const uint k_particle_row_update_params_bits = 14;
static const uint k_particle_row_const_params_bits = 14;
#endif

#define CS_PARTICLE_UPDATE_THREADS 64

CBUFFER_BEGIN(ParticleUpdateVS)
	CBUFFER_CONST(ParticleUpdateVS,			float,					delta_time,						k_vs_particle_update_delta_time)
	CBUFFER_CONST(ParticleUpdateVS,			float3,					delta_time_pad,					k_vs_particle_update_delta_time_pad)
CBUFFER_END

CBUFFER_BEGIN(ParticleState)
	CBUFFER_CONST(ParticleState,			s_all_state,			g_all_state,					k_particle_state_all_state)
CBUFFER_END

COMPUTE_TEXTURE_AND_SAMPLER(_2D,			sampler_weather_occlusion,		k_cs_sampler_weather_occlusion,			1)
COMPUTE_TEXTURE_AND_SAMPLER(_2D,			sampler_turbulence,				k_cs_sampler_turbulence,				2)

STRUCTURED_BUFFER(update_params_buffer,	k_cs_particle_update_params_buffer, 	s_particle_system_update_params,	5)
STRUCTURED_BUFFER(const_params_buffer,	k_cs_particle_const_params_buffer, 		s_particle_system_const_params,		6)

#if (DX_VERSION == 11) && (! defined(DEFINE_CPP_CONSTANTS))
static const uint k_particle_row_shift = 4;
static const uint k_particle_row_mask = 0xf;
static const uint k_particle_update_params_shift = k_particle_row_count_bits;
static const uint k_particle_update_params_mask = (1 << k_particle_row_update_params_bits) - 1;
static const uint k_particle_const_params_shift = k_particle_update_params_shift + k_particle_row_update_params_bits;
static const uint k_particle_const_params_mask = (1 << k_particle_row_const_params_bits) - 1;

static uint g_update_params_index;
static uint g_const_params_index;

#define g_all_properties const_params_buffer[g_const_params_index].m_all_properties
#define g_all_functions const_params_buffer[g_const_params_index].m_all_functions
#define g_all_colors const_params_buffer[g_const_params_index].m_all_colors
#define g_all_state update_params_buffer[g_update_params_index].m_all_state
#define g_update_state update_params_buffer[g_update_params_index].m_update_state
#define tile_to_world update_params_buffer[g_update_params_index].m_tile_to_world
#define world_to_tile update_params_buffer[g_update_params_index].m_world_to_tile
#define turbulence update_params_buffer[g_update_params_index].m_turbulence
#define turbulence_xform update_params_buffer[g_update_params_index].m_turbulence_xform
#define tiled update_params_buffer[g_update_params_index].m_tiled
#define collision update_params_buffer[g_update_params_index].m_collision
#endif

#endif
