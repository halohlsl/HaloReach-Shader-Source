#if DX_VERSION == 9

#if defined(VERTEX_SHADER)
s_fog_light_constants					k_vs_fog_constants : register(c236);		// v_atmosphere_constant_4;
s_atmosphere_precomputed_LUT_constants	k_vs_LUT_constants : register(c232);		// v_atmosphere_constant_0;
#endif

#elif DX_VERSION == 11

CBUFFER_BEGIN(AtmosphereFogVS)
	CBUFFER_CONST(AtmosphereFogVS,		s_atmosphere_precomputed_LUT_constants,	k_vs_LUT_constants,		k_vs_atmosphere_lut_constants)
	CBUFFER_CONST(AtmosphereFogVS,		s_fog_light_constants,					k_vs_fog_constants,		k_vs_atmosphere_fog_constants)
CBUFFER_END

SHADER_CONST_ALIAS(AtmosphereFogVS, s_atmosphere_constants, k_vs_atmosphere_constants, (s_atmosphere_constants)k_vs_LUT_constants, k_vs_screen_atm_fog_constants, k_vs_atmosphere_lut_constants, 0)

#endif
