#ifndef _HUD_CAMERA_NIGHTVISION_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _HUD_CAMERA_NIGHTVISION_REGISTERS_FX_
#endif

#ifdef VERTEX_SHADER
#define FOG_ENABLED
#include "shared\atmosphere_core.fx"
#endif

#if defined(VERTEX_SHADER) || defined(DEFINE_CPP_CONSTANTS)

#if DX_VERSION == 9

s_fog_light_constants					k_vs_fog_constants : register(c236);		// v_atmosphere_constant_4;
s_atmosphere_precomputed_LUT_constants	k_vs_LUT_constants : register(c240);		// v_lighting_constant_0;

#elif DX_VERSION == 11

CBUFFER_BEGIN(CheapParticleRenderVS)
	CBUFFER_CONST(CheapParticleRenderVS,	s_fog_light_constants,						k_vs_fog_constants,		k_vs_cheap_particles_fog_constants)
	CBUFFER_CONST(CheapParticleRenderVS,	s_atmosphere_precomputed_LUT_constants,		k_vs_LUT_constants,		k_vs_cheap_particles_LUT_constants)
CBUFFER_END

#endif

#endif

#endif
