//#line 2 "source\rasterizer\hlsl\restore_ldr_hdr_depth.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D ldr_sampler : register(s0);
sampler2D depth_sampler : register(s2);

struct triple_out
{
	float4 color[2] : COLOR0;
};

triple_out default_ps(screen_output IN, float2 pixel_coordinates : VPOS)
{
	triple_out out_colors;
	
	float4 ldr_color, hdr_color;
#ifdef pc
	ldr_color= tex2D(ldr_sampler, IN.texcoord);
#else
	asm
	{
		tfetch2D ldr_color, pixel_coordinates, ldr_sampler, UnnormalizedTextureCoords=true
	};
#endif
 	out_colors.color[1]= ldr_color;
 	
	float4 depth_color;
#ifdef pc
	depth_color= tex2D(depth_sampler, IN.texcoord);
#else
 	float column= pixel_coordinates.x / 80;
 	float halfcolumn= frac( column );
 	if( halfcolumn>= 0.5 )
 		pixel_coordinates.x-= 40;
    else
		pixel_coordinates.x+= 40;
	asm
	{
		tfetch2D depth_color.zyxw, pixel_coordinates, depth_sampler, UnnormalizedTextureCoords=true
	};
#endif
 	out_colors.color[0]= depth_color;
 	return out_colors;
}
