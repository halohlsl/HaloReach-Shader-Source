//#line 1 "source\rasterizer\hlsl\player_emblem_screen.hlsl"
/*
player_emblem_screen.hlsl
Copyright (c) Microsoft Corporation, 2007. All rights reserved.
Friday February 23, 2007, 12:05pm Stefan S.

*/

/* ---------- headers */

#define POSTPROCESS_COLOR

#define LDR_ONLY // needed for using convert_to_render_target()
#include "hlsl_constant_globals.fx"
#include "explicit\player_emblem.fx"
#include "postprocess\postprocess.fx"

// compile this shader for various needed vertex types
//@generate screen

/* ---------- public code */

// pixel fragment entry points

accum_pixel default_ps(screen_output IN) : SV_Target
{
	/*
	struct screen_output
	{
		float4 position		:POSITION;
		float2 texcoord		:TEXCOORD0;
		float4 color		:TEXCOORD1;
	};
	*/
	float4 emblem_pixel= calc_emblem(IN.texcoord, true);

	// cap transparency against the vertex color
	emblem_pixel.a= min(emblem_pixel.a, IN.color.a);

	return convert_to_render_target(emblem_pixel, false, false);
}
