#if DX_VERSION == 9

DECLARE_PARAMETER(float, block_size,		c80);
DECLARE_PARAMETER(bool, odd_bits,		b1);

#elif DX_VERSION == 11

CBUFFER_BEGIN(StencilStipplePS)
	CBUFFER_CONST(StencilStipplePS,	float,		block_size,		k_ps_stencil_stipple_block_size)
	CBUFFER_CONST(StencilStipplePS,	float3,		block_size_pad,	k_ps_stencil_stipple_block_size_pad)
	CBUFFER_CONST(StencilStipplePS,	bool,		odd_bits,		k_ps_stencil_stipple_bool_odd_bits)
CBUFFER_END

#endif
