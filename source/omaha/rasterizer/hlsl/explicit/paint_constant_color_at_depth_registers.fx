#if DX_VERSION == 9

DECLARE_PARAMETER(float, depth_value, c8);

#elif DX_VERSION == 11

CBUFFER_BEGIN(PaintConstantColorAtDepthPS)
	CBUFFER_CONST(PaintConstantColorAtDepthPS,	float,		depth_value,		k_ps_paint_constant_color_at_depth_depth_value)
CBUFFER_END

#endif
