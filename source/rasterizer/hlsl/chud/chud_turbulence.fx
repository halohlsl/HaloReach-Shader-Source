// ==== SHADER DOCUMENTATION
// shader: chud_turbulence
#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"

#define LDR_ONLY
#include "shared\render_target.fx"

#include "chud\chud_util.fx"

//@generate chud_simple
//@entry default
//@entry albedo
//@entry dynamic_light

// rename entry point of water passes
#define draw_turbulence_vs			default_vs
#define draw_turbulence_ps			default_ps
#define apply_to_distortion_vs		albedo_vs
#define apply_to_distortion_ps		albedo_ps
#define apply_to_blur_vs			default_dynamic_light_vs
#define apply_to_blur_ps			dynamic_light_ps

// The following defines the protocol for passing interpolated data between vertex/pixel shaders
struct s_chud_interpolators
{
	float4 position			:SV_Position;
	float2 texcoord			:TEXCOORD0;
};

// sampler of turbulence
LOCAL_SAMPLER_2D(chud_turbulence_sampler, 3);
static const float max_chud_distortion= 0.04f;


s_chud_interpolators draw_turbulence_vs(vertex_type IN)
{
    s_chud_interpolators OUT;

    float3 virtual_position= chud_local_to_virtual(IN.position.xy);
    OUT.position= chud_virtual_to_screen(virtual_position);
	OUT.texcoord= IN.texcoord.xy*chud_texture_transform.xy + chud_texture_transform.zw;
    return OUT;
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
	float4 bitmap_result= sample2D(basemap_sampler, texcoord);
	return bitmap_result;
#endif
}

// pixel fragment entry points
accum_pixel draw_turbulence_ps(s_chud_interpolators IN) : SV_Target
{
#ifndef pc
	float4 gradients;
	float2 texcoord= IN.texcoord;
	asm {
		getGradients gradients, texcoord, basemap_sampler
	};

	float4 result= 0.0;
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0,  2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients, -2.0/9.0, -2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0, -2.0/9.0));
	result+= texture_lookup(build_subsample_texcoord(texcoord, gradients,  2.0/9.0,  2.0/9.0));
	result /= 4.0;
#else // pc
	float4 result= texture_lookup(IN.texcoord);
#endif // pc

	// alpha testing
	clip(result.a-0.5f);

	// bias distortion
	result.xy= result.xy - 0.5f;
	result.x= -result.x; // reverse x, hack
	result.z= 0.0f;
	result.w= 0.0f;

	result.xy= result.xy*chud_widget_mirror_ps.xy;
    result.x= dot(result, chud_widget_transform1_ps.xyz);
    result.y= dot(result, chud_widget_transform2_ps.xyz);

	//return result;
	return convert_to_render_target(result, false, false);
}


s_chud_interpolators apply_to_distortion_vs(
	float4 position : POSITION,
	float4 texcoord : TEXCOORD0)
{
    s_chud_interpolators OUT;
    OUT.position= position;
	OUT.texcoord= texcoord.xy;
    return OUT;
}

float4 apply_to_distortion_ps(s_chud_interpolators IN) : SV_Target
{
	float4 result= sample2D(chud_turbulence_sampler, IN.texcoord);
	result.xy= max_chud_distortion * 2.0f * (result.xy - 0.5f);
#ifdef xenon
	result.xy *= 16.0f;
#endif
	return result;
}

s_chud_interpolators apply_to_blur_vs(
	float4 position : SV_Position,
	float4 texcoord : TEXCOORD0)
{
    s_chud_interpolators OUT;
    OUT.position= position;
	OUT.texcoord= texcoord.xy;
    return OUT;
}

float4 apply_to_blur_ps(s_chud_interpolators IN) : SV_Target
{
	float4 result= sample2D(chud_turbulence_sampler, IN.texcoord);
	result= result.z;
	return result;
}

// end of rename entry points
#undef draw_turbulence_vs
#undef draw_turbulence_ps
#undef apply_to_distortion_vs
#undef apply_to_distortion_ps
#undef apply_to_blur_vs
#undef apply_to_blur_ps
