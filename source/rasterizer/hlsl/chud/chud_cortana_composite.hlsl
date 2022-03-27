#line 1 "source\rasterizer\hlsl\chud_cortana_composite.hlsl"

#include "hlsl_constant_mapping.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#define LDR_ALPHA_ADJUST g_exposure.w
#define HDR_ALPHA_ADJUST g_exposure.b
#define DARK_COLOR_MULTIPLIER g_exposure.g
#include "shared\render_target.fx"
#include "chud\chud_util.fx"

#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif

#define CONSTANT_NAME(n) c##n
#include "postprocess\postprocess_registers.h"

PIXEL_CONSTANT(float4x3, p_postprocess_hue_saturation_matrix, k_postprocess_hue_saturation_matrix);


//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_simple
// 
// ---- COLOR OUTPUTS
// color output A= solid color
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
// G: selects between primary (0) and secondary (255) color
// B: highlight channel

sampler2D cortana_sampler : register(s1);
sampler2D goo_sampler : register(s2);

struct chud_output_cortana
{
	float4 HPosition	 :POSITION;
	float2 Texcoord		 :TEXCOORD0;
	float4 VirtualPos	 :TEXCOORD1; // <>
	float2 GooTexcoord	 :TEXCOORD2;
	float  hposition_z	 :TEXCOORD3;
};

chud_output_cortana default_vs(vertex_type IN)
{
    chud_output_cortana OUT;
    
    float3 virtual_position= chud_local_to_virtual(IN.position.xy);
    float3 virtual_position_unity= float3(
		virtual_position.x/chud_screen_size.z,
		virtual_position.y/chud_screen_size.w,
		virtual_position.z);
    
	OUT.VirtualPos= float4(virtual_position_unity, 0);
	float4 hposition= chud_virtual_to_screen(virtual_position);
    OUT.HPosition= hposition;
	OUT.Texcoord= float2((hposition.x + 0.5)/hposition.z, (1.0 - (hposition.y + 0.5))/hposition.z);
	OUT.GooTexcoord= IN.texcoord;
	OUT.hposition_z= hposition.z;
	
    return OUT;
}

float4 huesat(float4 in_color)
{
	return float4(mul(float4(in_color.x, in_color.y, in_color.z, 1.0f), p_postprocess_hue_saturation_matrix), 1.0);
}

float4 thresh(float4 in_color)
{
	float t_in= min(1.0, dot(in_color, cortana_comp_solarize_inmix));
	float result= step(cortana_comp_solarize_result.x, t_in)*pow((t_in - cortana_comp_solarize_result.x)/(1.0 - cortana_comp_solarize_result.x), cortana_comp_solarize_result.y);
	
	return float4(result*cortana_comp_solarize_outmix);
}

float4 centered_sample(float2 centered_texcoord, float scale, float t_value)
{
	float2 texcoord= (centered_texcoord*scale)*0.5 + float2(0.5, 0.5);
	return tex2D(cortana_sampler, texcoord);
}

float4 doubling(float2 texcoord)
{
	float2 centered= texcoord*2.0 - 1.0;
	
	float4 partial_result= 
		centered_sample(
			centered, 
			0.8*cortana_comp_doubling_result.z,
			0.75) + 
		centered_sample(
			centered, 
			0.5*cortana_comp_doubling_result.z,
			0.25);
			
	float val= dot(partial_result, cortana_comp_doubling_inmix);
	return cortana_comp_doubling_result.x*cortana_comp_doubling_outmix*val;
}

float4 comp_colorize(float4 in_color)
{
	float lum= min(1.0, dot(in_color, cortana_comp_colorize_inmix));
	float4 hsv_color= cortana_comp_colorize_result*float4(lum, lum, lum, lum);
	
	return hsv_color*cortana_comp_colorize_outmix;
}

float4 death_effect(float4 color, float key)
{
	float inten= color.r*(0.212671) + color.g*(0.715160) + color.b*(0.072169);
	float4 result= lerp(color, float4(inten, inten, inten, 0.0f), key);
	
	return result;
}

#define vignette_min cortana_vignette_data.x
#define vignette_max cortana_vignette_data.y

float4 gravemind_effect(float4 background, float4 foreground, float4 goo, float4 virtual_texcoord)
{
	float dist= distance(virtual_texcoord.xy, float2(0.5, 0.5));
	float vignette_t= (dist - vignette_min)/(vignette_max - vignette_min);
	vignette_t= clamp(vignette_t, 0.0, 1.0);
	float vignette= pow(vignette_t, 2.0);
	float floodification= 0.5*foreground.r+vignette;

	//background= death_effect(background, foreground.r, virtual_texcoord);
	background= background * (1.0 - (0.4*floodification*goo + 0.6*floodification));
	
	return background;
}

// pixel fragment entry points
accum_pixel default_ps(chud_output_cortana IN) : COLOR
{
	float2 adjusted_texcoord= IN.Texcoord*IN.hposition_z;
	float4 background= cortana_back_colormix_result*tex2D(basemap_sampler, adjusted_texcoord);
	float4 foreground= tex2D(cortana_sampler, adjusted_texcoord);
	float4 goo= tex2D(goo_sampler, IN.GooTexcoord);
	
	background= huesat(background);
	
	float4 background_gravemind= gravemind_effect(background, foreground, goo, IN.VirtualPos);
	
	foreground+= doubling(adjusted_texcoord);
	foreground+= thresh(foreground);
	
	if (chud_comp_colorize_enabled)
	{
		foreground= comp_colorize(foreground);
	}
	
	accum_pixel result_pixel;
	result_pixel.color= background_gravemind+foreground;

	return result_pixel;
	
	//return chud_compute_result_pixel(background+foreground);
}