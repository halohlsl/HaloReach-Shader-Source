//#line 1 "source\rasterizer\hlsl\transparent.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#include "shared\render_target.fx"

//@generate transparent

struct transparent_output
{
	float4 HPosition	:POSITION;
	float2 Texcoord		:TEXCOORD0;
	float4 Color		:COLOR0;
};

VERTEX_CONSTANT(float4, rigid_node0, c16);
VERTEX_CONSTANT(float4, rigid_node1, c17);
VERTEX_CONSTANT(float4, rigid_node2, c18);
VERTEX_CONSTANT(float4,	Position_Compression_Scale, c12);
VERTEX_CONSTANT(float4,	Position_Compression_Offset, c13);

transparent_output default_vs(vertex_type IN)
{
    transparent_output OUT;
    float4 position;

	position.xyz= IN.position.xyz*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;	
	position.w= 1.f;
	
	OUT.HPosition.x= dot(position, rigid_node0);
	OUT.HPosition.y= dot(position, rigid_node1);
	OUT.HPosition.z= dot(position, rigid_node2);
	OUT.HPosition.w= 1.f;

    OUT.HPosition= mul(OUT.HPosition, View_Projection);
    
    OUT.Color= IN.color;
	OUT.Texcoord= IN.texcoord;
	
    return OUT;
}

// pixel fragment entry points
accum_pixel default_ps(transparent_output IN) : COLOR
{
	return convert_to_render_target(float4(1.f, 1.f, 1.f, 1.f), false, false);
}
