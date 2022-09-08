//#line 2 "source\rasterizer\hlsl\explicit\cui_linear_gradient.hlsl"

#include "hlsl_constant_globals.fx"
#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : SV_Target
{
	float4 color = cui_tex2D(IN.texcoord);

	float4 top_left_color = k_cui_pixel_shader_color0;
	float4 top_right_color = k_cui_pixel_shader_color1;
	float4 bottom_left_color = k_cui_pixel_shader_color2;
	float4 bottom_right_color = k_cui_pixel_shader_color3;

	float4 top_color = top_left_color*(1-IN.texcoord.x) + top_right_color*IN.texcoord.x;
	float4 bottom_color = bottom_left_color*(1-IN.texcoord.x) + bottom_right_color*IN.texcoord.x;
	float4 gradient_color = top_color*(1-IN.texcoord.y) + bottom_color*IN.texcoord.y;

	color = cui_tint(color,
		cui_linear_to_gamma2(gradient_color),
		cui_linear_to_gamma2(k_cui_pixel_shader_tint));

	return color*scale;
}
