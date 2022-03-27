//#line 1 "source\rasterizer\hlsl\chud_meter_radial_gradient.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_meter_gradient
//
// note: the 'meter value' for this shader is implicit, not defined 
// in the texture! it's derived from the 'x' value of the texcoord,
// if the bitmap sequence is it's own bitmap (not a sub-rectangle of 
// a larger bitmap) then the left edge will have a meter value of '0'
// and the right edge will have a meter value of 'meter max' which
// is stored in [scalar output E]
// 
// ---- COLOR OUTPUTS
// color output A= primary color
// color output B= secondary color
// color output C= gradient color
// color output D= empty color
// 
// ---- SCALAR OUTPUTS
// scalar output A= meter amount
// scalar output B= unused
// scalar output C= unused
// scalar output D= unused
// scalar output E= unused
// scalar output F= unused

// ---- BITMAP CHANNELS
// A: alpha
// R: unused
// G: selects between primary (0) and secondary (255) color
// B: unused

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

	float4 result;
	result.rgb= bitmap_result.rgb*chud_color_output_A;
	result.a= bitmap_result.a;
	float pi= 3.141592637;

	float x_percentage= (texcoord.x-chud_scalar_output_ABCD.z)/(chud_scalar_output_ABCD.w-chud_scalar_output_ABCD.z);
	float y_percentage= (texcoord.y-chud_scalar_output_EF.x)/(chud_scalar_output_EF.y-chud_scalar_output_EF.x);

	float meter_angle= chud_scalar_output_ABCD.x*2*pi;
	float pixel_angle= 2*pi - (atan2(x_percentage-0.5, y_percentage-0.5)+pi);

	if (meter_angle<pixel_angle)
	{
		result.a= 0.0;
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