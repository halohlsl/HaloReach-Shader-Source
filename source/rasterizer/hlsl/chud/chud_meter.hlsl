//#line 1 "source\rasterizer\hlsl\chud_meter.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_meter
//
// ---- COLOR OUTPUTS
// color output A= primary color
// color output B= secondary color
// color output C= empty color
// color output D= flash color
// 
// ---- SCALAR OUTPUTS
// scalar output A= meter amount
// scalar output B= flash amount
// scalar output C= filled alpha scale (>1 makes filled more opaque)
// scalar output D= empty alpha scale (<1 makes empty less opaque)
// scalar output E= meter maximum
// scalar output F= unused

// ---- BITMAP CHANNELS
// A: alpha
// R: unused
// G: selects between primary (0) and secondary (255) color
// B: meter value

chud_output default_vs(vertex_type IN)
{
    chud_output OUT;

    float3 virtual_position= chud_local_to_virtual(IN.position.xy);
    OUT.MicroTexcoord= virtual_position.xy/4;
    OUT.HPosition= chud_virtual_to_screen(virtual_position);
	OUT.Texcoord= IN.texcoord.xy*chud_texture_transform.xy + chud_texture_transform.zw;

    return OUT;
}

float4 build_subpixel_result_shared_pc(float4 bitmap_result)
{
	float meter_amount= bitmap_result.b - chud_scalar_output_ABCD.x/chud_scalar_output_EF.x;

	float4 result= chud_color_output_C*(1-chud_scalar_output_ABCD.y) + chud_color_output_D*chud_scalar_output_ABCD.y;
	result.a= bitmap_result.a*(chud_scalar_output_ABCD.w*(1-chud_scalar_output_ABCD.y) + chud_scalar_output_ABCD.z*chud_scalar_output_ABCD.y);

	if (meter_amount<0)
	{
		result= chud_color_output_A*bitmap_result.g + chud_color_output_B*(1.0 - bitmap_result.g);
		result.a= bitmap_result.a*chud_scalar_output_ABCD.z;
	}

	result.a*=chud_scalar_output_EF.w;

	return result;
}

float4 build_subpixel_result_shared_xbox(float4 bitmap_result)
{
	float4 result= bitmap_result;

	result.a*=chud_scalar_output_EF.w;

	return result;
}

float4 build_subpixel_result(float2 texcoord)
{
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);
	return build_subpixel_result_shared_pc(bitmap_result);
}

float2 build_subsample_texcoord(float2 texcoord, float4 gradients, float dh, float dv)
{
	float2 result= texcoord;
	result+= gradients.xz*dh;
	result+= gradients.yw*dv;

	return result;
}

float4 meter_lookup(float2 texcoord)
{
#ifndef pc
	float4 bitmap_result;
	asm{
		tfetch2D bitmap_result, texcoord, basemap_sampler, MinFilter=point, MagFilter=point
	};

	float meter_amount= bitmap_result.b - chud_scalar_output_ABCD.x/chud_scalar_output_EF.x;

	float4 result= chud_color_output_C*(1-chud_scalar_output_ABCD.y) + chud_color_output_D*chud_scalar_output_ABCD.y;
	result.a= bitmap_result.a*(chud_scalar_output_ABCD.w*(1-chud_scalar_output_ABCD.y) + chud_scalar_output_ABCD.z*chud_scalar_output_ABCD.y);

	if (meter_amount<0.0)
	{
		result= chud_color_output_A*bitmap_result.g + chud_color_output_B*(1.0 - bitmap_result.g);
		result.a= bitmap_result.a*chud_scalar_output_ABCD.z;
	}

	return result;
#else
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);
	return bitmap_result;
#endif
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
	result+= meter_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0,  2.0/9.0));
	result+= meter_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0, -2.0/9.0));
	result+= meter_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0, -2.0/9.0));
	result+= meter_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0,  2.0/9.0));
	result /= 4.0;
	result= build_subpixel_result_shared_xbox(result);	
#else // pc
	float4 result= build_subpixel_result(IN.Texcoord);
#endif // pc

	return chud_compute_result_pixel(result);
}
