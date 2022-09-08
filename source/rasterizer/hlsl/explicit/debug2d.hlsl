//#line 1 "source\rasterizer\hlsl\debug2d.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"

//@generate debug

struct debug_output
{
   float4 HPosition	:SV_Position;
   float3 Color		:COLOR0;
};

debug_output default_vs(vertex_type IN)
{
   debug_output OUT;

   OUT.HPosition.xy= IN.position.xy;
   OUT.HPosition.zw= 1.f;
   OUT.Color= IN.color;

   return OUT;
}

// pixel fragment entry points

float4 default_ps(debug_output IN) : SV_Target
{
    return float4(IN.Color, 1.0f);
}
