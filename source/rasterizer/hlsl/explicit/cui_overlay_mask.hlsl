//#line 2 "source\rasterizer\hlsl\cui_overlay_mask.hlsl"

#include "explicit\cui_hlsl.fx"
//@generate screen

float4 default_ps(screen_output IN) : COLOR
{
	float4 color0= cui_tex2D(IN.texcoord);
	float4 color1= cui_tex2D_secondary(IN.texcoord);
	
	float4 color = color0 * color1;
	color.a = 1 - (1 - color0.a) * (1 - color1.a);
	
	color = cui_tint(color, cui_linear_to_gamma2(k_cui_pixel_shader_tint));
	
	return color*scale;
}
