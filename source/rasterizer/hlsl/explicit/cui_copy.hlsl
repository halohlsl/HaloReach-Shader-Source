//#line 2 "source\rasterizer\hlsl\cui_copy.hlsl"

#include "hlsl_constant_globals.fx"
#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : SV_Target
{
	float4 color= cui_tex2D(IN.texcoord);

	color = cui_tint(color, cui_linear_to_gamma2(k_cui_pixel_shader_tint*IN.color));

	return color*scale;
}
