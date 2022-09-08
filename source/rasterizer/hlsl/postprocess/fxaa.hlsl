//#line 1 "source\rasterizer\hlsl\fxaa.hlsl"

#include "global.fx"
#include "hlsl_vertex_types.fx"
#include "templated\entry.fx"
#include "postprocess\fxaa_registers.fx"
#include "postprocess\postprocess_registers.fx"

//@generate screen
//@entry default
//@entry albedo
//@entry static_sh
//@entry shadow_generate,
//@entry shadow_apply,
//@entry active_camo,
//@entry lightmap_debug_mode,
//@entry water_tessellation

#define SCREEN_WIDTH_RCP   k_postprocess_pixel_size.x
#define SCREEN_HEIGHT_RCP  k_postprocess_pixel_size.y


#define HLSL_ATTRIB_ISOLATE [isolate]
#define HLSL_ATTRIB_UNROLL  [unroll]
#define HLSL_ATTRIB_BRANCH  [branch]


#define FXAA_PC 1
#if DX_VERSION == 9
#define FXAA_HLSL_3 1
#elif DX_VERSION == 11
#define FXAA_HLSL_5 1
#endif

#define FXAA_PRESET_default 10
#define FXAA_PRESET_albedo 12
#define FXAA_PRESET_static_sh 14
#define FXAA_PRESET_shadow_generate 15
#define FXAA_PRESET_shadow_apply 20
#define FXAA_PRESET_active_camo 24
#define FXAA_PRESET_lightmap_debug_mode 28
#define FXAA_PRESET_water_tessellation 39

#define VS_NAME(name) name##_vs
#define PS_NAME(name) name##_ps
#define PRESET_NAME(name) FXAA_PRESET_##name

#define VERTEX_SHADER_NAME VS_NAME(entry_point)
#define PIXEL_SHADER_NAME PS_NAME(entry_point)
#define FXAA_QUALITY__PRESET PRESET_NAME(entry_point)


//#define FXAA_GREEN_AS_LUMA 1


#define __fxaaQualitySubpix  0.25f
#define __fxaaQualityEdgeThreshold 0.166f
#define __fxaaQualityEdgeThresholdMin 0.0833f

struct EDGE_AA_VS_OUTPUT
{
   float2 uv : TEXCOORD0; // center
   float4 uv1: TEXCOORD1; // left, right
   float4 uv2: TEXCOORD2; // top,  bottom
   float4 uv3: TEXCOORD3; // left-top, right-bottom
   float4 uv4: TEXCOORD4; // left-bottom, right-top
};

#ifndef VERTEX_SHADER
#include "postprocess\fxaa3_11.fx"
#endif

LOCAL_SAMPLER_2D(source_sampler, 0);

struct VS_OUTPUT
{
   float4 hpos : SV_Position;
   EDGE_AA_VS_OUTPUT edge_aa;
};


VS_OUTPUT VERTEX_SHADER_NAME(vertex_type IN)
{
   VS_OUTPUT   res;

   res.hpos.xy = IN.position;
   res.hpos.z  = 0.5f;
   res.hpos.w  = 1.0f;

   //float2 TEXEL_SIZE = float2(1.0f / 1280.0f, 1.0f / 720.0f);

   float2 C  = IN.texcoord.xy;
   float2 L  = C + float2(-TEXEL_SIZE.x, 0);
   float2 R  = C + float2(TEXEL_SIZE.x, 0);
   float2 T  = C + float2(0, -TEXEL_SIZE.y);
   float2 B  = C + float2(0, TEXEL_SIZE.y);
   float2 RT = float2(R.x, T.y);
   float2 LT = float2(L.x, T.y);
   float2 RB = float2(R.x, B.y);
   float2 LB = float2(L.x, B.y);
   res.edge_aa.uv = C;
   res.edge_aa.uv1.xy = L;
   res.edge_aa.uv1.zw = R;
   res.edge_aa.uv2.xy = T;
   res.edge_aa.uv2.zw = B;
   res.edge_aa.uv3.xy = LT;
   res.edge_aa.uv3.zw = RB;
   res.edge_aa.uv4.xy = LB;
   res.edge_aa.uv4.zw = RT;

   return res;
}


// pixel fragment entry points
#ifndef VERTEX_SHADER

float4 PIXEL_SHADER_NAME(
	SCREEN_POSITION_INPUT(screen_position),
	EDGE_AA_VS_OUTPUT input) : SV_Target
{
   //return tex2D(source_sampler, input.uv.xy);
   //return FxaaPixelShader(source_sampler, input);

   return FxaaPixelShader(input.uv.xy,
      source_sampler,
      pixel_size.xy,
      __fxaaQualitySubpix,
      __fxaaQualityEdgeThreshold,
      __fxaaQualityEdgeThresholdMin
   );
}

#endif
