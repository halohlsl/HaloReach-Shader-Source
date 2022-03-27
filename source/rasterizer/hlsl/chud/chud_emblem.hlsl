//#line 1 "source\rasterizer\hlsl\chud_emblem.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

#undef PIXEL_CONSTANT
#undef VERTEX_CONSTANT
#include "explicit\player_emblem.fx"

//@generate chud_simple


// ==== SHADER DOCUMENTATION
// shader: chud_emblem
// 
// ---- COLOR OUTPUTS
// color output A= primary background color
// color output B= secondary background color
// color output C= highlight color
// color output D= flash color
// 
// ---- SCALAR OUTPUTS
// scalar output A= flash value; if 1, uses 'flash color', if 0 uses blended primary/secondary background
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



chud_output default_vs(vertex_type IN)
{
    chud_output OUT;

    float3 virtual_position= chud_local_to_virtual(IN.position.xy);
    OUT.MicroTexcoord= virtual_position.xy/4;
    OUT.HPosition= chud_virtual_to_screen(virtual_position);
	OUT.Texcoord= IN.texcoord.xy*chud_texture_transform.xy + chud_texture_transform.zw;

    return OUT;
}



// pixel fragment entry points
accum_pixel default_ps(chud_output IN) : COLOR
{
	float4	emblem_pixel=	calc_emblem(IN.Texcoord, false);

	return chud_compute_result_pixel(emblem_pixel);
}

