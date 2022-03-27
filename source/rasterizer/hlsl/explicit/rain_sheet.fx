#ifndef INCLUDED_BY_C_PLUS_PLUS_CODE

#define SCOPE_MESH_DEFAULT
#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "templated\entry.fx"
//@generate patchy_fog
//@entry default
//@generate rigid
//@entry albedo
//@generate rigid
//@entry active_camo


#define cylinder_rain_sheet_vs	default_vs
#define cylinder_rain_sheet_ps	default_ps

#if ENTRY_POINT(entry_point) == ENTRY_POINT_albedo

#define vertical_rain_sheet_vs	albedo_vs
#define inward_face_ps			albedo_ps

#elif ENTRY_POINT(entry_point) == ENTRY_POINT_active_camo


#define vertical_rain_sheet_vs	active_camo_vs
#define outward_face_ps			active_camo_ps

#endif

#include "shared\render_target.fx"


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT

#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
	
	#define VERTEX_CONSTANT_EX(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT_EX(type, name, register_index)
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	
	#define VERTEX_CONSTANT_EX(type, name, register_index)
	#define PIXEL_CONSTANT_EX(type, name, register_index)   type name : register(c##register_index);
#endif

#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);


#endif //INCLUDED_BY_C_PLUS_PLUS_CODE


// shared constants with patchy fog
PIXEL_CONSTANT(float4, inverse_z_transform, 32)
PIXEL_CONSTANT_EX(float4, sheer_and_attenuation_data, 34)
PIXEL_CONSTANT(float4, eye_position, 35)
PIXEL_CONSTANT(float4, window_pixel_bounds, 36)

// dedicated constants for rain sheets
PIXEL_CONSTANT_EX(float4, movement_and_intervals, 52)
PIXEL_CONSTANT(float4, intensity_and_scale, 53)
PIXEL_CONSTANT_EX(float4, texture_stretch, 54)
PIXEL_CONSTANT_EX(float4, movement0, 55)
PIXEL_CONSTANT_EX(float4, movement1, 56)
PIXEL_CONSTANT_EX(float4, movement2, 57)
PIXEL_CONSTANT_EX(float4, movement3, 58)

BOOL_CONSTANT(vs_arctangent_base, 1)
BOOL_CONSTANT(ps_arctangent_base, 1)

PIXEL_CONSTANT(float4, shadow_proj, 59)
PIXEL_CONSTANT(float4, shadow_depth, 60)

VERTEX_CONSTANT(float4x4, inv_View_Projection, 20)
VERTEX_CONSTANT_EX(float4, sheer_and_attenuation_data, 24)
VERTEX_CONSTANT_EX(float4, movement_and_intervals, 25)
VERTEX_CONSTANT_EX(float4, movement0, 26)
VERTEX_CONSTANT_EX(float4, movement1, 27)
VERTEX_CONSTANT_EX(float4, movement2, 28)
VERTEX_CONSTANT_EX(float4, movement3, 29)
VERTEX_CONSTANT_EX(float4, texture_stretch, 30)

#ifndef INCLUDED_BY_C_PLUS_PLUS_CODE

#define LAYER0_WEIGHT 1
#define LAYER1_WEIGHT 1
#define LAYER2_WEIGHT 1
#define LAYER3_WEIGHT 0

struct s_vertex_out
{
	float4 position : POSITION;
	float2 texcoord : TEXCOORD0;
	float4 world_space : TEXCOORD1;
};

struct s_cylinder_rain_sheet_vertex_out
{
	float4 position : POSITION;
	float3 relative_pos : TEXCOORD0;	
	float3 view_vector : TEXCOORD2;
	float3 sheet_depths: TEXCOORD3;
	float4 rain_tex_coord01: TEXCOORD4;
	float2 rain_tex_coord2: TEXCOORD6;
};

s_cylinder_rain_sheet_vertex_out cylinder_rain_sheet_vs(
	s_patchy_fog_vertex vertex_in
	)
{
	const float min_distance=movement_and_intervals.z;
	    
	s_cylinder_rain_sheet_vertex_out vertex_out;
		
	vertex_out.position= vertex_in.position;
	float4 world_space_with_w= mul(vertex_in.position, transpose(inv_View_Projection));
	float3 world_space= world_space_with_w/world_space_with_w.w;
	
	float3 view_vector= world_space - Camera_Position;
	float scale= length(view_vector.xy);
	vertex_out.relative_pos.xyz= view_vector.xyz/scale * min_distance;
	
	view_vector= normalize(view_vector);
	
	view_vector.xy+=view_vector.z * sheer_and_attenuation_data.xy;
	
	vertex_out.view_vector= view_vector;	
	
    float xy_proj_legnth= length(view_vector.xy);
    float fake_height= -view_vector.z/xy_proj_legnth * min_distance;
    
	float depth= length( float2( 1, fake_height)) * min_distance;
	    
	float increace= movement_and_intervals.w;
	    
	float depth_accumulation= depth * increace;
	
    
    float angle;
    if(vs_arctangent_base)
    {
		angle=atan2(-view_vector.y, -view_vector.x);
	}
	else
	{
		angle=atan2(view_vector.y, view_vector.x);
	}
		
	float3 sheet_depths;
	sheet_depths.x= depth;
	sheet_depths.y= sheet_depths.x+depth_accumulation;
	sheet_depths.z= sheet_depths.y+depth_accumulation;
	vertex_out.sheet_depths= sheet_depths;
	

    float2 scaled_vector_in_world_space= float2(angle * min_distance, fake_height);
	vertex_out.rain_tex_coord01.xy= ( scaled_vector_in_world_space + movement0 ) * texture_stretch.x ;
	vertex_out.rain_tex_coord01.zw= ( scaled_vector_in_world_space + movement1 ) * texture_stretch.y ;
	vertex_out.rain_tex_coord2= ( scaled_vector_in_world_space + movement2 ) * texture_stretch.z ;
	
	return vertex_out;
}

float3 transform_point(in float4 position, in float4 node[3])
{
	float3 result;

	result.x= dot(position, node[0]);
	result.y= dot(position, node[1]);
	result.z= dot(position, node[2]);

	return result;
}


s_vertex_out vertical_rain_sheet_vs(
	s_rigid_vertex vertex_in
	)
{
	s_vertex_out vertex_out;
	
	float4 position;
	position.xyz= vertex_in.position*Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
	position.w= 1.0f;
	position.xyz= transform_point(position, Nodes[0]);
	
	
	vertex_out.position= mul(position, View_Projection);
	vertex_out.world_space= position;
	vertex_out.texcoord= vertex_in.texcoord*UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;	
	
	return vertex_out;
}

// Noise texture sampled for fog density
sampler tex_noise : register(s0);

// Scene depth texture sampled to fade fog near scene intersections
sampler tex_scene_depth : register(s1);

sampler occlusion_height : register(s2);

#define TOTAL_MIE_LOG2E				atmosphere_constant_3.xyz  // TOTAL_MIE * log2(e)


#define k_log2_e	(log2(exp(1)))

// LDR entrypoint
//float4 default_ps(s_vertex_out pixel_in, float2 screen_position : VPOS) : COLOR0

#define pi 3.14159265358979323846

float4 fade(float4 depth_diff, float exp_coeff, float step_distance)
{
	float4 depth_fade_factor;
#if 0
	depth_fade_factor= 1.0f - exp(-depth_diff.xyzw * sheer_and_attenuation_data.z);
	return saturate(depth_fade_factor);	
#else
	depth_fade_factor= smoothstep( float4(0,0,0,0), float4(step_distance,step_distance,step_distance,step_distance), depth_diff);
	return saturate(depth_fade_factor);	
#endif
}

float evaluate_density( float optical_depth )
{	
#if 0
	return 1.0f-exp2(-TOTAL_MIE_LOG2E.x * optical_depth);
#else
	return saturate(optical_depth * intensity_and_scale.x );
#endif
}
// HDR entrypoint
accum_pixel cylinder_rain_sheet_ps(s_cylinder_rain_sheet_vertex_out pixel_in, float2 screen_position : VPOS)
{
	int i;
	
#ifndef pc
	float4 scene_depth_vector;
    asm{ tfetch3D scene_depth_vector, screen_position, tex_scene_depth, UnnormalizedTextureCoords= true};
    float scene_depth= scene_depth_vector.x;
#else
	float scene_depth=0;
#endif
	
	// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
	float2 view_space_scene_depth= inverse_z_transform.xy * scene_depth + inverse_z_transform.zw;
	// Homogenous divide
	view_space_scene_depth.x/= -view_space_scene_depth.y;
	
	
	float3 view_vector= pixel_in.view_vector.xyz;
	
	float2 texturecoordinate;
	float3 sheet_depths0= pixel_in.sheet_depths;
	float4 noise_values0;
    float distance_between_sheets= movement_and_intervals.y;
	{
	    float min_distance=movement_and_intervals.z;
	    
		{
	        {
    		    noise_values0.x= tex2D(tex_noise, pixel_in.rain_tex_coord01.xy).x * LAYER0_WEIGHT;    		    
				{
    				float2 position= pixel_in.relative_pos.xy;
    				
					float2 shadow_texcoord = position.xy * shadow_proj.xy + float2(0.5f,0.5f);
					float4 shadow=0;
	#ifndef pc
					asm
					{
						tfetch2D	shadow,	shadow_texcoord.xy,	occlusion_height,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
					};
					float4 occluder_h= shadow.x * shadow_depth.x + shadow_depth.y;
					clip(pixel_in.relative_pos.z - occluder_h);
	#endif
				}   		    
		        
    		    
	        }
	        {
    		    noise_values0.y= tex2D(tex_noise, pixel_in.rain_tex_coord01.zw).x * LAYER1_WEIGHT;   		    
	        }
	        {
    		    noise_values0.z= tex2D(tex_noise, pixel_in.rain_tex_coord2).x * LAYER2_WEIGHT;    		    
	        }
	        {
    		    noise_values0.w= LAYER3_WEIGHT;
	        }
	    }	    
	}	
	
	// This value is positive whenever a sheet is visible (e.g. in front of the existing scene)
	// and negative when a sheet is further away than the current scene point.
	float4 view_space_depth_diff0= float4(view_space_scene_depth.xxx - sheet_depths0.xyz, 0);
	
	float4 fade_factor0= fade(view_space_depth_diff0, sheer_and_attenuation_data.z, distance_between_sheets);
	
	float optical_depth= dot(fade_factor0, noise_values0);
	
	float extinction= evaluate_density( optical_depth ); 
	
	float double_multiply_adjust= lerp(0.5f, 1,  extinction)/32.0f;
		
	return convert_to_render_target( float4( float3(1,1,1) * double_multiply_adjust  , extinction), false, true);
}


// HDR entrypoint
accum_pixel inward_face_ps(s_vertex_out pixel_in, float2 screen_position : VPOS)
{
	int i;
	
#ifndef pc
	float4 scene_depth_vector;
    asm{ tfetch3D scene_depth_vector, screen_position, tex_scene_depth, UnnormalizedTextureCoords= true};
    float scene_depth= scene_depth_vector.x;
#else
	float scene_depth=0;
#endif
		
	// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
	float2 view_space_scene_depth= inverse_z_transform.xy * scene_depth + inverse_z_transform.zw;
	// Homogenous divide
	view_space_scene_depth.x/= -view_space_scene_depth.y;
	
	
    float min_distance=movement_and_intervals.z;
	float3 view_vector= pixel_in.world_space.xyz - eye_position;
	float vertical_sheet_depth= length( view_vector.xy );
	clip(vertical_sheet_depth-min_distance*0.95f);
	
	view_vector.xy+=view_vector.z * sheer_and_attenuation_data.xy;

	view_vector/=vertical_sheet_depth;
	
	float2 texturecoordinate;
	float4 sheet_depths0;
	float4 noise_values0;
	float distance_between_sheets=movement_and_intervals.y;
	{
	    float vertical_movement=movement_and_intervals.x;
	    
	    float angle;
	    if(ps_arctangent_base)
	    {
			angle=atan2(-view_vector.y, -view_vector.x);
		}
		else
		{
			angle=atan2(view_vector.y, view_vector.x);
		}
	    
	    float xy_proj_legnth=length(view_vector.xy);
	    
	    float2 unit_vector=float2(angle,-view_vector.z/xy_proj_legnth);

	    float2 scaled_vector_in_world_space=unit_vector*min_distance;
	    
	    float depth=length( float2( 1, unit_vector.y)) * min_distance;
	    
	    float increace= movement_and_intervals.w;//movement_and_intervals.y/min_distance;
	    
	    float depth_accumulation=depth*increace;
	    
		{
			float4 transparency;
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement0 )*texture_stretch.x ;
				sheet_depths0.x= depth;
				transparency.x= 1- smoothstep(sheet_depths0.x, sheet_depths0.x+distance_between_sheets, vertical_sheet_depth);
    		    noise_values0.x= tex2D(tex_noise, texture_coordinate).x * LAYER0_WEIGHT;
	        }
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement1) * texture_stretch.y;
				sheet_depths0.y= sheet_depths0.x+depth_accumulation;
				transparency.y= 1- smoothstep(sheet_depths0.y, sheet_depths0.y+distance_between_sheets, vertical_sheet_depth);
    		    noise_values0.y= tex2D(tex_noise,texture_coordinate).x * LAYER1_WEIGHT;   		    
	        }
	        {
				float2 texture_coordinate=( scaled_vector_in_world_space + movement2) * texture_stretch.z;
				sheet_depths0.z= sheet_depths0.y+depth_accumulation;
				transparency.z= 1- smoothstep(sheet_depths0.z, sheet_depths0.z+distance_between_sheets, vertical_sheet_depth);
    		    noise_values0.z= tex2D(tex_noise,texture_coordinate).x * LAYER2_WEIGHT;    		    
	        }
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement3) * texture_stretch.w;
				sheet_depths0.w= sheet_depths0.z+depth_accumulation;
				transparency.w= 1- smoothstep(sheet_depths0.w, sheet_depths0.w+distance_between_sheets, vertical_sheet_depth);
    		    noise_values0.w= tex2D(tex_noise,texture_coordinate).x * LAYER3_WEIGHT;
	        }
	        noise_values0*=transparency;
	        
	        if(transparency.x==0)
	        {
				float weight= 3 - dot(transparency,float4(1,1,1,1));
				float2 texture_coordinate;
				texture_coordinate= pixel_in.texcoord;
				texture_coordinate.y-=vertical_movement+eye_position.z;
    		    noise_values0.x= tex2D(tex_noise,texture_coordinate * intensity_and_scale.y ).x * weight;
    		    sheet_depths0.x= vertical_sheet_depth;    		    
	        }
	    }	    
	}	
	
	// This value is positive whenever a sheet is visible (e.g. in front of the existing scene)
	// and negative when a sheet is further away than the current scene point.
	float4 view_space_depth_diff0= view_space_scene_depth.xxxx - sheet_depths0.xyzw;
	
	float4 fade_factor0= fade(view_space_depth_diff0, sheer_and_attenuation_data.z, distance_between_sheets);
	
	float optical_depth= dot(fade_factor0, noise_values0);
	
	float extinction= evaluate_density( optical_depth ); 
		
	float double_multiply_adjust= lerp(0.5f, 1,  extinction)/32.0f;
		
	return convert_to_render_target( float4( float3(1,1,1) * double_multiply_adjust  , extinction), false, true);
}

// HDR entrypoint
accum_pixel outward_face_ps(s_vertex_out pixel_in, float2 screen_position : VPOS)
{
	int i;
	
#ifndef pc
	float4 scene_depth_vector;
    asm{ tfetch2D scene_depth_vector, screen_position, tex_scene_depth, UnnormalizedTextureCoords= true};
    float scene_depth= scene_depth_vector.x;
#else
	float scene_depth=0;
#endif
		
	// Convert the depth from [0,1] to view-space homogenous (.xy = _33 and _43, .zw = _34 and _44 from the projection matrix)
	float2 view_space_scene_depth= inverse_z_transform.xy * scene_depth + inverse_z_transform.zw;
	// Homogenous divide
	view_space_scene_depth.x/= -view_space_scene_depth.y;
	
	
    float min_distance=movement_and_intervals.z;
	float3 view_vector= pixel_in.world_space - eye_position;
	float vertical_sheet_depth= length( view_vector.xy );
	clip(vertical_sheet_depth-min_distance*0.95f);
	view_vector.xy+=view_vector.z * sheer_and_attenuation_data.xy;

	view_vector/=vertical_sheet_depth;
	
	view_space_scene_depth= min(view_space_scene_depth, vertical_sheet_depth);
	
	float2 texturecoordinate;
	float4 sheet_depths0;
	float4 noise_values0;
    float distance_between_sheets=movement_and_intervals.y;
	{
	    float vertical_movement=movement_and_intervals.x;
	    
	    float angle;
	    if(ps_arctangent_base)
	    {
			angle=atan2(-view_vector.y, -view_vector.x);
		}
		else
		{
			angle=atan2(view_vector.y, view_vector.x);
		}
	    
	    float xy_proj_legnth= length(view_vector.xy);
	    
	    float2 unit_vector= float2(angle,-view_vector.z/xy_proj_legnth);

	    float2 scaled_vector_in_world_space= unit_vector * min_distance;
	    
	    float depth= length( float2( 1, unit_vector.y)) * min_distance;
	    
	    float increace= movement_and_intervals.w;//movement_and_intervals.y/min_distance;
	    
	    float depth_accumulation= depth * increace;
	    
		{
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement0 )*texture_stretch.x ;
				sheet_depths0.x= depth;
    		    noise_values0.x= tex2D(tex_noise, texture_coordinate).x * LAYER0_WEIGHT;
	        }
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement1) * texture_stretch.y;
				sheet_depths0.y= sheet_depths0.x+depth_accumulation;
    		    noise_values0.y= tex2D(tex_noise,texture_coordinate).x * LAYER1_WEIGHT;   		    
	        }
	        {
				float2 texture_coordinate=( scaled_vector_in_world_space + movement2) * texture_stretch.z;
				sheet_depths0.z= sheet_depths0.y+depth_accumulation;
    		    noise_values0.z= tex2D(tex_noise,texture_coordinate).x * LAYER2_WEIGHT;    		    
	        }
	        {
				float2 texture_coordinate= ( scaled_vector_in_world_space + movement3) * texture_stretch.w;
				sheet_depths0.w= sheet_depths0.z+depth_accumulation;
				noise_values0.w= tex2D(tex_noise,texture_coordinate).x * LAYER3_WEIGHT;
	        }
	    }	    
	}	
	
	// This value is positive whenever a sheet is visible (e.g. in front of the existing scene)
	// and negative when a sheet is further away than the current scene point.
	float4 view_space_depth_diff0= view_space_scene_depth.xxxx - sheet_depths0.xyzw;
	
	float4 fade_factor0= fade(view_space_depth_diff0, sheer_and_attenuation_data.z, distance_between_sheets);
	
	float optical_depth= dot(fade_factor0, noise_values0);
	
	float extinction= evaluate_density( optical_depth ); 
	
	float double_multiply_adjust= lerp(0.5f, 1,  extinction)/32.0f;
		
	return convert_to_render_target( float4( float3(1,1,1) * double_multiply_adjust  , extinction), false, true);
}

#endif //!INCLUDED_BY_C_PLUS_PLUS_CODE