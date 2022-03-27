//#line 2 "source\rasterizer\hlsl\explicit\cui_change_channel.hlsl"
#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : COLOR
{
 	float4 color= cui_tex2D(IN.texcoord);
 	
	float4 multiply_color = float4(k_cui_pixel_shader_scalar1, k_cui_pixel_shader_scalar2, k_cui_pixel_shader_scalar3, k_cui_pixel_shader_scalar0);
 	
 	color = cui_tint(color, cui_linear_to_gamma2(k_cui_pixel_shader_tint));

 	return color*scale;
}
