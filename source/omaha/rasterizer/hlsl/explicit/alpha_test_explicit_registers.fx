#ifndef _ALPHA_TEST_EXPLICIT_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _ALPHA_TEST_EXPLICIT_REGISTERS_FX_
#endif

#if DX_VERSION == 9

VERTEX_CONSTANT(float4, lighting, k_alpha_test_shader_lighting_constant);

#elif DX_VERSION == 11

CBUFFER_BEGIN(AlphaTestExplicitVS)
	CBUFFER_CONST(AlphaTestExplicitVS,	float4,	lighting,	k_alpha_test_shader_lighting_constant)
CBUFFER_END

#endif

#endif
