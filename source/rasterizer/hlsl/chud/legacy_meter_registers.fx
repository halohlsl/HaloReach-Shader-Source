#ifndef _LEGACY_METER_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _LEGACY_METER_REGISTERS_FX_
#endif

#if DX_VERSION == 9

PIXEL_CONSTANT(float4, meter_amount_constant, POSTPROCESS_EXTRA_PIXEL_CONSTANT_3);

#elif DX_VERSION == 11

CBUFFER_BEGIN(LegacyMeterPS)
	CBUFFER_CONST(LegacyMeterPS,	float4,		meter_amount_constant,		k_ps_legacy_meter_amount)
CBUFFER_END

#endif

#endif

