//#line 1 "source\rasterizer\hlsl\chud_damage_tracker.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#define IGNORE_SCREENSHOT_TILING
#include "chud\chud_util.fx"

//@generate chud_simple

#define health_t chud_scalar_output_ABCD.x
#define recent_damage_t chud_scalar_output_ABCD.y
#define fade_min chud_scalar_output_ABCD.z
#define fade_max chud_scalar_output_ABCD.w
#define chud_damage_tracker_color chud_color_output_A

// ==== SHADER DOCUMENTATION
// shader: chud_damage_tracker
//
// ---- COLOR OUTPUTS
// color output A= fade color
// color output B= unused
// color output C= unused
// color output D= unused
//
// ---- SCALAR OUTPUTS
// scalar output A= scaled health
// scalar output B= scaled damage
// scalar output C= health fade start
// scalar output D= health fade stop
// scalar output E= unused
// scalar output F= unused

// ---- BITMAP CHANNELS
// A: alpha
// R: unused
// G: unused
// B: unused

chud_output default_vs(vertex_type IN)
{
    chud_output OUT;

    float3 virtual_position= chud_local_to_virtual(IN.position.xy);

    OUT.MicroTexcoord= virtual_position.xy/4;
    OUT.HPosition= chud_virtual_to_screen(virtual_position);
	OUT.Texcoord= float2(virtual_position.x/chud_screen_size.z, virtual_position.y/chud_screen_size.w);

    return OUT;
}

// pixel fragment entry points
float4 default_ps(chud_output IN) : SV_Target
{
	float x= abs(IN.Texcoord.x-0.5);
	float y= abs(IN.Texcoord.y-0.5);
	float outer_t= max(x, y);
	outer_t= (outer_t-fade_min)/(fade_max-fade_min);

	float dist= distance(IN.Texcoord, float2(0.5, 0.5));

	float inner_dist= sqrt(2*(fade_min*fade_min))*.85;
	float outer_dist= sqrt(2*(fade_max*fade_max));

	float t= (dist-inner_dist)/(outer_dist-inner_dist);

	t*= 1.5;

	outer_t= max(outer_t, t);
	outer_t= clamp(outer_t, 0.0, 1.0);

	outer_t= pow(outer_t, 1.5);

	outer_t= outer_t*(1.0-health_t);
	float inner_t= recent_damage_t;
	return float4(chud_damage_tracker_color.xyz, max(outer_t, inner_t)/128);
}

#undef health_t
#undef recent_damage_t
#undef fade_min
#undef fade_max
#undef chud_damage_tracker_color
