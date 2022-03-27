#line 2 "source\rasterizer\hlsl\stencil_restore.hlsl"

#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen

sampler2D source_sampler : register(s0);

float4 default_ps(screen_output IN, in float2 vpos : VPOS) : COLOR
{
#ifdef pc
 	return 0.0f;
#else
	// exchange every other 40-pixel column

	float column=			floor(vpos.x / 80.0f);										// which 80 wide column we are in
	float sub_column_pos=	vpos.x - column * 80.0f;									// 0..79
	float sub_column=		floor(sub_column_pos / 40.0f);								// left (0) or right (1) 40 wide sub column
	float new_x=			40.0f - 80.0f * (sub_column - column) + sub_column_pos;		// flip and re-assemble
	vpos.x= new_x;
 
	float4 result;
	asm {
		tfetch2D result, vpos, source_sampler, UnnormalizedTextureCoords = true, MagFilter = point, MinFilter = point, MipFilter = point, AnisoFilter = disabled
	};
	return result.bbbb;		// stencil is stored in the blue channel
#endif
}
