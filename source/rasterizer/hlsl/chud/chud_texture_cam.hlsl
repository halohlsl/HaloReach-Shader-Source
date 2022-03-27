//#line 1 "source\rasterizer\hlsl\chud_texture_cam.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_texture_cam
// 
// ---- COLOR OUTPUTS
// color output A= unused
// color output B= unused
// color output C= unused
// color output D= unused
// 
// ---- SCALAR OUTPUTS
// scalar output A= unused
// scalar output B= unused
// scalar output C= unused
// scalar output D= unused
// scalar output E= unused
// scalar output F= unused

// ---- BITMAP CHANNELS
// A: alpha
// R: unused
// G: selects between primary (255) and secondary (0) color
// B: highlight channel

sampler2D texturecam_sampler : register(s1);

chud_output default_vs(vertex_type IN)
{
    chud_output OUT;

    float3 virtual_position= chud_local_to_virtual(IN.position.xy);
    OUT.MicroTexcoord= virtual_position.xy/4;
    OUT.HPosition= chud_virtual_to_screen(virtual_position);
	OUT.Texcoord= IN.texcoord.xy*chud_texture_transform.xy + chud_texture_transform.zw;

    return OUT;
}

float4 build_subpixel_result(float2 texcoord)
{
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);
	float4 texcam_result= tex2D(texturecam_sampler, texcoord);
	bitmap_result.rgb*=texcam_result.rgb;

	return bitmap_result;
}

// pixel fragment entry points
accum_pixel default_ps(chud_output IN) : COLOR
{
	float4 result= build_subpixel_result(IN.Texcoord);

	return chud_compute_result_pixel(result);
}
