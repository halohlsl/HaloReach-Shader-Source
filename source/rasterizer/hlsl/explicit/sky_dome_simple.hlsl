//#line 2 "source\rasterizer\hlsl\write_depth.hlsl"

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"

#include "shared\render_target.fx"

//@generate sky

struct VS_INPUT
{
	float3 vPos : POSITION;
	float3 vColor : TEXCOORD0;
	float3 vNormal : NORMAL;
};

struct VS_OUTPUT
{
	float4 pos : POSITION;
	float3 color : TEXCOORD0;
	float3 normal : TEXCOORD1;
};

VS_OUTPUT default_vs(VS_INPUT input)
{
	VS_OUTPUT output;

	float4 world_pos;
	world_pos.xyz= transform_point(float4(input.vPos, 1.0f), Nodes[0]);
	world_pos.w= 1.0f;
	output.pos= mul(world_pos, View_Projection);
	output.color= input.vColor;
	output.normal= normalize(input.vPos);

	return output;
}

accum_pixel default_ps(VS_OUTPUT input)
{

	float4 out_color= float4(input.color * g_exposure.rrr, 1.0f);

#ifdef xenon
	float3 sun= pow(max(dot(p_lighting_constant_0.xyz, normalize(input.normal)), 0.0f), p_lighting_constant_0.w) * p_lighting_constant_1.rgb;
#else // PC
	// pc shader compiler has a bug somewhere...  the above line doesn't compile
	float3 sun= pow(max(dot(p_lighting_constant_0.xyz, normalize(input.normal)), 0.0f), 2.0) * p_lighting_constant_1.rgb;
#endif // PC
    out_color.rgb+= sun;

	return convert_to_render_target(out_color, true, false);
		
}
