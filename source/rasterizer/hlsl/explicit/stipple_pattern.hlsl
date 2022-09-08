//#line 2 "source\rasterizer\hlsl\stipple_pattern.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
//@generate screen

struct screen_output
{
	float4 HPosition	:SV_Position;
};

screen_output default_vs(vertex_type IN)
{
    screen_output OUT;

    OUT.HPosition.xy= IN.position;
    OUT.HPosition.zw= 0.5f;

    return OUT;
}

uint4 default_ps(SCREEN_POSITION_INPUT(position)) : SV_Target0
{
	uint2 ipos = uint2(position.xy);

	uint result = 0;
	result |= (ipos.y & 2) >> 1;
	result |= ((ipos.x ^ ipos.y) & 2);
	//result |= (ipos.y & 1) << 2;
	//result |= ((ipos.x ^ ipos.y) & 1) << 3;

	return result;
}
