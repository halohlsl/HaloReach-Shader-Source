//#line 1 "source\rasterizer\hlsl\chud_meter_shield.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_meter_shield
// 
// ---- COLOR OUTPUTS
// color output A= primary color
// color output B= secondary color
// color output C= shield-flash color
// color output D= empty color
// color output E= flash color
// 
// ---- SCALAR OUTPUTS
// scalar output A= shield amount
// scalar output B= shield recent damage
// scalar output C= shield-flash alpha scale (>1 makes flash less opaque)
// scalar output D= empty alpha scale (<1 makes empty more opaque)
// scalar output E= flash amount
// scalar output F= unused

// ---- BITMAP CHANNELS
// A: alpha
// R: unused
// G: selects between primary (0) and secondary (255) color
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

float4 build_subpixel_result(float2 texcoord)
{
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);

#ifndef pc
	asm{
		tfetch2D bitmap_result, texcoord, basemap_sampler, MinFilter=linear, MagFilter=linear
	};
#else
	bitmap_result= tex2D(basemap_sampler, texcoord);
#endif

	float this_meter_value= 255.0*bitmap_result.b;
	float regular_meter_value= chud_scalar_output_ABCD.x;
	float previous_meter_value= chud_scalar_output_ABCD.y;
	float shield_flash_gradient_radius= 0.25*(previous_meter_value - regular_meter_value);
	float shield_flash_gradient_min= regular_meter_value;
	float shield_flash_gradient_max= regular_meter_value + shield_flash_gradient_radius;

	float shield_flash_amount= 0;
	float flash_amount= chud_scalar_output_EF.x;

	if (this_meter_value>shield_flash_gradient_min)
	{
		if (this_meter_value<shield_flash_gradient_max)
		{
			shield_flash_amount= (this_meter_value - shield_flash_gradient_min)/(shield_flash_gradient_max-shield_flash_gradient_min);
		}
		else
		{
			shield_flash_amount= 1.0;
		}
	}

	float4 result= chud_color_output_D*(1.0-flash_amount) + chud_color_output_E*flash_amount;
	result.a= bitmap_result.a*((1.0-flash_amount)*chud_scalar_output_ABCD.w + flash_amount);

	if (this_meter_value<=previous_meter_value)
	{
		float4 base_color= chud_color_output_A * (1.0f - bitmap_result.g) + chud_color_output_B*bitmap_result.g;
	
		result= base_color*(1.0 - shield_flash_amount) + chud_color_output_C*(shield_flash_amount);
		result.a= bitmap_result.a*(1.0 - shield_flash_amount) + (bitmap_result.a*chud_scalar_output_ABCD.z)*shield_flash_amount;
	}

	return result;
}

float2 build_subsample_texcoord(float2 texcoord, float4 gradients, float dh, float dv)
{
	float2 result= texcoord;
	result+= gradients.xz*dh;
	result+= gradients.yw*dv;

	return result;
}

// pixel fragment entry points
accum_pixel default_ps(chud_output IN) : COLOR
{
#ifndef pc
	float4 gradients;
	float2 texcoord= IN.Texcoord;

	{
		[isolate]		// ###ctchou $TODO this isolate is to work around a bug in the HLSL compiler crashing when it tries to optimize this instruction.   it should be fixed in future releases and we can remove this line
		asm {
			getGradients gradients, texcoord, basemap_sampler 
		};
	}

	float4 result= 0.0;
	result+= build_subpixel_result(build_subsample_texcoord(texcoord, gradients, -2.0/9.0,  2.0/9.0));
	result+= build_subpixel_result(build_subsample_texcoord(texcoord, gradients, -2.0/9.0, -2.0/9.0));
	result+= build_subpixel_result(build_subsample_texcoord(texcoord, gradients,  2.0/9.0, -2.0/9.0));
	result+= build_subpixel_result(build_subsample_texcoord(texcoord, gradients,  2.0/9.0,  2.0/9.0));
	result /= 4.0;
	result.a*=chud_scalar_output_EF.w;
#else // pc
	float4 result= build_subpixel_result(IN.Texcoord);
	result.a*=chud_scalar_output_EF.w;
#endif // pc

	return chud_compute_result_pixel(result);
}
