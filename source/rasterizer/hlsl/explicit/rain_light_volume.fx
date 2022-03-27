#ifndef INCLUDED_BY_C_PLUS_PLUS_CODE

//#line 1 "source\rasterizer\hlsl\debug.hlsl"

// define before render_target.fx
#ifndef LDR_ALPHA_ADJUST
#ifdef pc
#define LDR_ALPHA_ADJUST 1.0f
#else
#define LDR_ALPHA_ADJUST 1.0f/32.0f
#endif
#endif
#ifndef DARK_COLOR_MULTIPLIER
#define DARK_COLOR_MULTIPLIER 128.0f
#endif

#define LDR_ONLY

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "shared\render_target.fx"
#include "templated\entry.fx"

#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);

sampler rain: register(s0);
sampler2D	tex_scene_depth : register(s1);

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif

#endif //INCLUDED_BY_C_PLUS_PLUS_CODE

PIXEL_CONSTANT(float4, lighting_position_and_cutoff, 112)
PIXEL_CONSTANT(float4, lighting_color_and_falloff_ratio, 113)
PIXEL_CONSTANT(float4, lighting_direction_and_attenuation, 114)
PIXEL_CONSTANT(float4, lighting_falloff_speed_view_direction, 115)
PIXEL_CONSTANT(float4, inverse_z_transform, 116)


VERTEX_CONSTANT(float4, movement_and_intensity, 200)
VERTEX_CONSTANT(float4x3, rotation, 201)
VERTEX_CONSTANT(float3, project_texture_cooridnate0, 204)
VERTEX_CONSTANT(float3, project_texture_cooridnate1, 205)

#ifndef INCLUDED_BY_C_PLUS_PLUS_CODE

//@generate debug

struct debug_output
{
	float4 HPosition	:POSITION;
    float4 coordinate_and_intensity_and_camera_z :COLOR0;
    float4 light_space_position_and_camera_w: TEXCOORD0;
};

debug_output default_vs(vertex_type IN)
{
    debug_output OUT;

    float3 transformed_position= mul(float4(IN.position.xyz, 1), rotation);
    
    OUT.light_space_position_and_camera_w.xyz= IN.position.xyz;
    
    OUT.HPosition= mul(float4(transformed_position, 1.0f), View_Projection);
    float3 offset= transformed_position - project_texture_cooridnate1;
    float projectedx= dot (offset, project_texture_cooridnate0)*movement_and_intensity.x;
    
	OUT.coordinate_and_intensity_and_camera_z.xy= float2(projectedx, movement_and_intensity.z + transformed_position.z)
		+IN.color.rg;
	OUT.coordinate_and_intensity_and_camera_z.z= IN.color.a * movement_and_intensity.y;
	
	OUT.coordinate_and_intensity_and_camera_z.w= OUT.HPosition.z;
	OUT.light_space_position_and_camera_w.w= OUT.HPosition.w;
	
    return OUT;
}

// pixel fragment entry points

accum_pixel default_ps(debug_output IN, float2 screen_position : VPOS)
{
	float distance= length(IN.light_space_position_and_camera_w.xyz);
	float distance_falloff= 1-saturate(distance/lighting_direction_and_attenuation.w);
	distance_falloff*= distance_falloff;
	
	float3 dir=IN.light_space_position_and_camera_w.xyz/distance;
	float angle_fall_off= saturate((dir.z-lighting_position_and_cutoff.w)*lighting_color_and_falloff_ratio.w);
	
	float angle_falloff= pow(angle_fall_off, lighting_falloff_speed_view_direction.w);
	
	float falloff= distance_falloff*angle_falloff;
	
	float4 rain_texture;
	#ifndef pc
	float2 texcoord= IN.coordinate_and_intensity_and_camera_z.xy;
	asm
	{
		tfetch2D rain_texture, texcoord, rain, LODBias=-.5
	};
	#else
	rain_texture= tex2D(rain, IN.coordinate_and_intensity_and_camera_z.xy);
	#endif
	
	
	float4 color= rain_texture*IN.coordinate_and_intensity_and_camera_z.z*falloff*float4(lighting_color_and_falloff_ratio.rgb,1);
	
	{
		float scene_depth=0;
#ifndef pc
		float4 scene_depth_vector;

		// hardware doesn't support this!!!
		asm{
			tfetch2D scene_depth_vector, screen_position, tex_scene_depth, UnnormalizedTextureCoords= true, MagFilter= point,	MinFilter= point,	MipFilter= point,	UseComputedLOD= false, UseRegisterGradients= false, AnisoFilter=disabled
		};

		// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
		float2 view_space_scene_depth= inverse_z_transform.xy * scene_depth_vector.x + inverse_z_transform.zw;
		// Homogenous divide		
		scene_depth= -view_space_scene_depth.x/view_space_scene_depth.y;		
#endif		

		float rain_sheet_depth=0;
#ifndef pc
		// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
		float2 rain_sheet_depth_vector= inverse_z_transform.xy * IN.coordinate_and_intensity_and_camera_z.w/IN.light_space_position_and_camera_w.w + inverse_z_transform.zw;
		// Homogenous divide			
		
		rain_sheet_depth= -rain_sheet_depth_vector.x/rain_sheet_depth_vector.y;
#endif
		float scene_depth_diff= scene_depth-rain_sheet_depth;
		//scene_depth_diff= scene_depth-IN.light_space_position_and_camera_w.w;
		
		float depth_fade= saturate(scene_depth_diff);
		
		color.rgb*= depth_fade;  // we're using additive mode.		
		color.a= saturate(color.a)*depth_fade;
	}
	
    return convert_to_render_target(color, false, false);
}

#endif