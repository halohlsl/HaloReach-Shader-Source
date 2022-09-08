//#line 2 "source\rasterizer\hlsl\cui_copy.hlsl"

#include "hlsl_constant_globals.fx"
#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : SV_Target
{
	return cui_linear_to_gamma2(k_cui_pixel_shader_tint) * scale;
}
