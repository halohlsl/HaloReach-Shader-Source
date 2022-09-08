#line 1 "source\rasterizer\hlsl\cui_emblem.hlsl"
/* ---------- headers */
#include "hlsl_constant_globals.fx"
#include "explicit\player_emblem.fx"
#include "explicit\cui_hlsl.fx"

// compile this shader for various needed vertex types
//@generate screen

/* ---------- public code */

// pixel fragment entry points

float4 default_ps(screen_output IN) : SV_Target
{
	float4	emblem_pixel=	calc_emblem(IN.texcoord, true);

	return emblem_pixel * scale;			// cui_tint(emblem_pixel, k_cui_pixel_shader_tint) * scale;
}

