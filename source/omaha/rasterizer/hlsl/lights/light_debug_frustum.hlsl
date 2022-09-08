//#line 1 "source\rasterizer\hlsl\light_debug_frustom.hlsl"


//@generate tiny_position
//@entry default

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "templated\deform.fx"
#include "shared\utilities.fx"
#include "shared\atmosphere.fx"

#define LDR_ALPHA_ADJUST g_exposure.w
#define HDR_ALPHA_ADJUST g_exposure.b
#define DARK_COLOR_MULTIPLIER g_exposure.g
#include "shared\render_target.fx"

#include "shared\texture_xform.fx"

#include "lights\light_apply_base_registers.fx"

#define LIGHT_COLOR		(light_colour_falloff_power.yzw)


// default for hard shadow
void default_vs(
	in vertex_type vertex,
	out float4 screen_position : SV_Position,
	out float3 world_position : TEXCOORD0)
{
    float4 local_to_world_transform[3];
	deform_tiny_position_projective(vertex, local_to_world_transform);
	world_position=	vertex.position;
	screen_position= mul(float4(vertex.position.xyz, 1.0f), View_Projection);
}


//sampler2D unused_sampler : s10;

float3 calc_normal_from_position(
	in float3 fragment_position_world)
{
/*
#ifndef pc
	float4 gradient_horz, gradient_vert;

	// gradient_vert=	dx/dv, dy/dv, dx/dh, dy/dh
	// gradient_horz=	dz/dh, dz/dv, dz/dh, dz/dv
	asm {
		getGradients gradient_vert.ywxz, fragment_position_world.xy, unused_sampler
		getGradients gradient_horz.xyzw, fragment_position_world.zz, unused_sampler
	};

//	gradient_horz.xy=	gradient_vert.zw;		// gradient_horz=	dx/dh, dy/dh, dz/dh, dz/dv
//	gradient_vert.z=	gradient_horz.w;		// gradient_vert=	dx/dv, dy/dv, dz/dv, dy/dh
//
//	float3 bump_normal=	normalize( -cross(gradient_horz.xyz, gradient_vert.xyz) );
//	return bump_normal;

	float3 color=		float3(gradient_horz.xyz);
	color=	normalize(color);
	return color;
#else // PC
*/
	float3 dBPx= ddx(fragment_position_world);		// worldspace gradient along pixel x direction
	float3 dBPy= ddy(fragment_position_world);		// worldspace gradient along pixel y direction
	float3 bump_normal= -normalize( cross(dBPx, dBPy) );
	return bump_normal;
//#endif // PC
}


accum_pixel default_ps(
	SCREEN_POSITION_INPUT(pixel_pos),
	in float3 world_position : TEXCOORD0)
{
#if defined(pc) && (DX_VERSION == 9)
 	float3 color= float3(1.0f, 1.0f, 0.0f);
#else

	float3 normal=	calc_normal_from_position(world_position);
	float3 color=	normal.xyz * 0.5f + 0.5f;

//	float3 color=	frac(world_position);
#endif

	color	=	LIGHT_COLOR * 0.6f + 0.4f * color;

	return convert_to_render_target(float4(color.rgb * g_exposure.rrr, 0.9f), false, true);
}

