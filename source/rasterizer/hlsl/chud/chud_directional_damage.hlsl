//#line 1 "source\rasterizer\hlsl\chud_directional_damage.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#define IGNORE_SCREENSHOT_TILING
#include "chud\chud_util.fx"

//@generate chud_simple


// ==== SHADER DOCUMENTATION
// shader: chud_directional_damage
// 
// special case shader, called manually in code.  not for chud widget use


chud_output default_vs(
	vertex_type IN)
{
    chud_output OUT;

	float3 virtual_position= chud_local_to_virtual(IN.position.xy);
	OUT.MicroTexcoord= IN.texcoord.xy;
	OUT.HPosition= chud_virtual_to_screen(virtual_position);
	OUT.Texcoord= chud_virtual_to_screen(virtual_position);

    return OUT;
}


float4 handle_screen_flash(
	float2 screen_position,
	float4 data,
	float4 color,
	float4 scale)
{
	//We want the flash to be its biggest and brightest when the crosshair is over the flash,
	//which means that the center of the flash is not the point you are getting shot from
	//but offset above the point by the magic crosshair offset
	float distance_to_flash= distance(screen_position, data.xy-chud_screen_flash_center.xy);
	float flash_distance_to_center= distance(data.xy, float2(0,0));
	float size= data.z*(1.0 - flash_distance_to_center) + data.w*flash_distance_to_center;
	float size_alpha= scale.x*(1.0 - flash_distance_to_center) + scale.y*flash_distance_to_center;

	if (distance_to_flash<size)
	{
		float t_to_center= max(0.0, 1.0 - distance_to_flash/(size));
		float inner_outer_blend= cos(t_to_center*3.141592)*-0.5 + 0.5;
		float4 result;
		result= color * size_alpha * (inner_outer_blend*scale.z + (1.0f - inner_outer_blend)*scale.w);

		return result;
	}
	else
	{
		return float4(0,0,0,0);
	}
}

float get_screen_flash_alpha(
	float2 screen_position)
{
	float2 difference_vector= screen_position;
	difference_vector.xy/= (chud_screen_flash_scale.xx);
	float t= distance(difference_vector, float2(0,0));

	float intensity= cos(t*3.141592)*-0.5 + 0.5;
	intensity= pow(intensity, chud_screen_flash_scale.y);
	intensity= (intensity*chud_screen_flash_scale.w + (1.0f - intensity)*chud_screen_flash_scale.z);

	return intensity;
}

// pixel fragment entry points
float4 default_ps(
	chud_output IN) : SV_Target
{
	float4 result=		handle_screen_flash(IN.Texcoord.xy, chud_screen_flash0_data, chud_screen_flash0_color, chud_screen_flash0_scale);
	result	+=			handle_screen_flash(IN.Texcoord.xy, chud_screen_flash1_data, chud_screen_flash1_color, chud_screen_flash1_scale);
	result	+=			handle_screen_flash(IN.Texcoord.xy, chud_screen_flash2_data, chud_screen_flash2_color, chud_screen_flash2_scale);
	result	+=			handle_screen_flash(IN.Texcoord.xy, chud_screen_flash3_data, chud_screen_flash3_color, chud_screen_flash3_scale);

	result.a *=			get_screen_flash_alpha(IN.Texcoord.xy);

	// clamp maximum total alpha
	//float clamped_alpha= min(result.a, 0.3);

	// re-scale weighted colors to match the clamped alpha
	//result.rgba= result.rgba * clamped_alpha / max(result.a, 0.0001);

	result.rgb	*=		result.a;

	result= float4(sqrt(result.rgb), result.a);

	return result;
}
