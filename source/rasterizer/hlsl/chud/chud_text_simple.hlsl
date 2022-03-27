//#line 1 "source\rasterizer\hlsl\chud_text_simple.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple

// ==== SHADER DOCUMENTATION
// shader: chud_text_simple
// 
// ---- COLOR OUTPUTS 
// color output A= text color
// color output B= flash color
// color output C= unused
// color output D= unused
// 
// ---- SCALAR OUTPUTS
// scalar output A= unused (usually the string number value)
// scalar output B= flash value; if 1, uses 'flash color', if 0 uses blended primary/secondary background
// scalar output C= unused
// scalar output D= unused
// scalar output E= unused
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

float4 build_subpixel_result_shared(float4 bitmap_result)
{
	float max_color= max(bitmap_result.r, max(bitmap_result.g, bitmap_result.b));
	float min_color= min(bitmap_result.r, min(bitmap_result.g, bitmap_result.b));
	float4 result= chud_color_output_A*(1.0 - chud_scalar_output_ABCD.y) + chud_color_output_B*chud_scalar_output_ABCD.y;
	
//	if (min_color!=max_color)								// can't do absolute math on floating point data
	if ((max_color - min_color) > 0.0002f)
	{
		result.rgb= bitmap_result.rgb;
	}
	
	result.a= bitmap_result.a;
	result.a*=chud_scalar_output_EF.w;
	
	return result;
}

float4 build_subpixel_result(float2 texcoord)
{
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);	
	return build_subpixel_result_shared(bitmap_result);
}

float2 build_subsample_texcoord(float2 texcoord, float4 gradients, float dh, float dv)
{
	float2 result= texcoord;
	result+= gradients.xz*dh;
	result+= gradients.yw*dv;
	
	return result;
}

float4 texture_lookup(float2 texcoord)
{
#ifndef pc
	float4 bitmap_result;
	asm{
	tfetch2D bitmap_result, texcoord, basemap_sampler, MinFilter=linear, MagFilter=linear
	};
	return bitmap_result;
#else
	float4 bitmap_result= tex2D(basemap_sampler, texcoord);
	return bitmap_result;
#endif
}

// pixel fragment entry points
accum_pixel default_ps(chud_output IN) : COLOR
{
#ifndef pc
	float subsample_scale= 1.0/9.0;

	float4 gradients;
	float2 texcoord= IN.Texcoord;
	
	asm {
		getGradients gradients, texcoord, basemap_sampler 
	};
	
	//gradients*=2.0;
	
	//gradients*=2.0;
	//float4 result= subsample_scale*build_subpixel_result(IN.Texcoord);
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, 1.0/3.0, -1.0/3.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, 1.0/3.0, 0.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, 1.0/3.0, 1.0/3.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, -1.0/3.0, -1.0/3.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, -1.0/3.0, 0.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, -1.0/3.0, 1.0/3.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, 0.0, -1.0/3.0));
	//result+= subsample_scale*build_subpixel_result(build_subsample_texcoord(texcoord, gradients, 0.0, 1.0/3.0));
	
	//float4 result= tex2D(basemap_sampler, IN.Texcoord);
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, 1.0/3.0, -1.0/3.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, 1.0/3.0, 0.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, 1.0/3.0, 1.0/3.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, -1.0/3.0, -1.0/3.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, -1.0/3.0, 0.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, -1.0/3.0, 1.0/3.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, 0.0, -1.0/3.0));
	//result+= tex2D(basemap_sampler, build_subsample_texcoord(texcoord, gradients, 0.0, 1.0/3.0));
	//result= build_subpixel_result_shared(result * subsample_scale);
	
	float4 result= 0.0;
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0,  2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0, -2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0, -2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0,  2.0/9.0));
	result /= 4.0;
	result= build_subpixel_result_shared(result);	
	
#else // pc
	float4 result= build_subpixel_result(IN.Texcoord);
#endif // pc

	return chud_compute_result_pixel(result);
}
