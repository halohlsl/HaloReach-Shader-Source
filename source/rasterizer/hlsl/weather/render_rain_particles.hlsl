////#line 1 "source\rasterizer\hlsl\weather\render_rain_particles.hlsl"
//@generate tiny_position
//@entry default
//@generate tiny_position
//@entry albedo

#define VERTS_PER_DROP			4
#define DROP_TEXTURE_SIZE		128

#include "hlsl_constant_globals.fx"

//#define QUAD_INDEX_MOD4
#include "shared\procedural_geometry.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#include "weather\rain_registers.h"
#include "templated\entry.fx"


bool particle_alpha_blend : register(b7);


#define light_volume_vs albedo_vs
#define light_volume_ps albedo_ps

#ifdef pc

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }
void albedo_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 albedo_ps() : COLOR0							{ return 0.0f; }

#else // XENON

sampler2D	drop_texture : register(s0);
//sampler2D	shadow_texture : register(s1);


#ifdef VERTEX_SHADER
void default_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION,
	out float4	out_texcoord			:	TEXCOORD0)
{
    // what raindrop are we?   4 verts per raindrop
	float drop_index= floor(index * (1.0f / VERTS_PER_DROP) + (0.5f / VERTS_PER_DROP));
	float vert_index= index - drop_index * VERTS_PER_DROP;

	float2 drop_coord;
	drop_coord.y=	floor(drop_index * (1.0f / DROP_TEXTURE_SIZE) + (0.5f / DROP_TEXTURE_SIZE));
	drop_coord.x=	drop_index - drop_coord.y *  DROP_TEXTURE_SIZE;

	// fetch rain drop data
	float4 drop_data;
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
	};
	float alpha=	drop_data.y;

	{
		float3 drop_position_cube=		float3(drop_coord / DROP_TEXTURE_SIZE, drop_data.x) + virtual_offset.xyz;
		float3 drop_position_world=		center.xyz + center.w * (drop_position_cube - floor(drop_position_cube) - 0.5f);

		float4 prev_drop_position_world=	mul(float4(drop_position_world, 1.0f), transpose(position_to_previous_position));
//		prev_drop_position_world.xyz	*=	1.0f / prev_drop_position_world.w;										// we can remove this normalization because the transform should be a pure rotation/offset

		float3 local_velocity=			drop_position_world.xyz - prev_drop_position_world.xyz;						// ###ctchou $TODO we might be able to build this into the matrix if we don't really need to know previous position
		float  speed=					length(local_velocity);
	
		float3 drop_to_camera_world=	drop_position_world - Camera_Position;
		float distance=	length(drop_to_camera_world.xyz);
		drop_to_camera_world /= distance;
	
		// basis contains velocity vector, and attempts to face screen
		float3x3 basis;
		basis[0]= -local_velocity.xyz / speed;										// normalize(velocity.xyz);
		basis[1]= normalize(cross(basis[0], drop_to_camera_world));
		basis[2]= -cross(basis[0], basis[1]);
	
		float2 local_pos=	generate_quad_point_2d(vert_index) * DROP_SIZE + DROP_OFFSET;
		
		float aspect_ratio=	min(max(speed / DROP_SIZE, 1.0f), DROP_MAX_ASPECT);			// MIN_ASPECT only applies to the transparency amount
		local_pos.x *=		aspect_ratio;
		alpha /=			max(DROP_MIN_ASPECT, aspect_ratio);					// reduce alpha based on aspect ratio (blurred drops are more see-through) -- stops the rain drops appearing brighter when they move faster.  stop when it hits min_aspect
		
		out_position=		float4(drop_position_world + mul(local_pos, basis), 1.0f);
		out_position=		mul(out_position, transpose(view_projection));
		
		alpha *= saturate(distance * DROP_NEAR_FADE_SCALE + DROP_NEAR_FADE_OFFSET);
	}

	if (alpha <= 0.0f)
	{
		out_position.xyz=	NaN;
	}
	
	out_texcoord.xy=							generate_quad_point_2d(vert_index);
	out_texcoord.z=	out_texcoord.a=				alpha;
}



void light_volume_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION,
	out float4	out_texcoord			:	TEXCOORD0,
	out float3	out_color				:	TEXCOORD1)
{
    // what raindrop are we?   4 verts per raindrop
	float drop_index= floor(index * (1.0f / VERTS_PER_DROP) + (0.5f / VERTS_PER_DROP));
	float vert_index= index - drop_index * VERTS_PER_DROP;


	float2 light_cube_coord;
	light_cube_coord.x= floor(drop_index/LIGHT_CUBE_SIZE_IN_TXEL);
	light_cube_coord.y= drop_index - light_cube_coord.x*LIGHT_CUBE_SIZE_IN_TXEL;

	float2 drop_coord= light_cube_coord+LIGHT_CUBE_TO_VIRTUAL_CUBE_OFFSET;
	
#if 1
	// normliazed texture coordinate doesn't work with wrap!
	drop_coord= drop_coord-floor(drop_coord/DROP_TEXTURE_SIZE)*DROP_TEXTURE_SIZE;    
	// fetch rain drop data
	float4 drop_data;
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
	};
#else
	// Not tested, but save some ALU	
	drop_data= tex2d(drop_texture, drop_coord/DROP_TEXTURE_SIZE);
#endif
	float alpha= 1.0f;		// drop_data.y;		// ignore occlusion

	{
		float3 drop_position_cube= float3(light_cube_coord/LIGHT_CUBE_SIZE_IN_TXEL, drop_data.x) + float3(0,0,virtual_offset.z);
		float3 normalized_position= drop_position_cube - floor(drop_position_cube) - 0.5f;
		float3 cube_scale= float3(LIGHT_CUBE_SIZE_LENGTH, LIGHT_CUBE_SIZE_LENGTH, center.w);
		
		float3 centered_position= cube_scale * normalized_position;
		centered_position.z= fmod(centered_position.z+LIGHT_CUBE_Z_WRAP/2, LIGHT_CUBE_Z_WRAP)-LIGHT_CUBE_Z_WRAP/2;
		
		float3 drop_position_world=		center.xyz + centered_position;

		float4 prev_drop_position_world=	mul(float4(drop_position_world, 1.0f), transpose(position_to_previous_position));
//		prev_drop_position_world.xyz	*=	1.0f / prev_drop_position_world.w;										// we can remove this normalization because the transform should be a pure rotation/offset

		float3 local_velocity=			drop_position_world.xyz - prev_drop_position_world.xyz;						// ###ctchou $TODO we might be able to build this into the matrix if we don't really need to know previous position
		float  speed=					length(local_velocity);
	
		float3 drop_to_camera_world=	normalize(drop_position_world - Camera_Position);
	
		// basis contains velocity vector, and attempts to face screen
		float3x3 basis;
		basis[0]= -local_velocity.xyz / speed;
		basis[1]= normalize(cross(basis[0], drop_to_camera_world));
		basis[2]= -cross(basis[0], basis[1]);
	
		float2 local_pos=	generate_quad_point_2d(vert_index) * DROP_SIZE + DROP_OFFSET;

		float aspect_ratio=	min(max(speed / DROP_SIZE, 1.0f), DROP_MAX_ASPECT);			// MIN_ASPECT only applies to the transparency amount
		local_pos.x *=		aspect_ratio;
		alpha /=			max(DROP_MIN_ASPECT, aspect_ratio);					// reduce alpha based on aspect ratio (blurred drops are more see-through) -- stops the rain drops appearing brighter when they move faster.  stop when it hits min_aspect
		
		out_position=		float4(drop_position_world + mul(local_pos, basis), 1.0f);
		
		{
			float3 particle_to_light= out_position-lighting_position_and_cutoff;
			float distance= length(particle_to_light);
			float3 direction= particle_to_light/distance;
			
			float dot_product= dot(direction, lighting_direction_and_attenuation.xyz);
			
			float angle_fall_off= saturate((dot_product-lighting_position_and_cutoff.w)*lighting_color_and_falloff_ratio.w);
			
			float specular= saturate(dot(lighting_falloff_speed_view_direction.xyz, direction))*2;
			
			
			float distance_fall_off= saturate(1 - distance/lighting_direction_and_attenuation.w);
			distance_fall_off*=distance_fall_off;
			
			float falloff= pow(angle_fall_off, lighting_falloff_speed_view_direction.w)* distance_fall_off;
			
			out_color= 
				//float3(drop_data.x, 1-drop_data.x, .5)*
				lighting_color_and_falloff_ratio.rgb * falloff * (1 + specular*specular*specular);			// ###ctchou $TODO move light color to pixel shader, reduce interpolation cost
			
			/*
			// We're rastierzation and fill bound or Vertex Shader ALU bound.
			// It doesn't really help
			if (out_color.x+out_color.y+out_color.z<=0)
			{
				out_position= NaN;
			}
			*/			
			
			out_color *= alpha;
		}
		
		out_position=		mul(out_position, transpose(view_projection));
	}
	
	out_texcoord.xy=			generate_quad_point_2d(vert_index);
	out_texcoord.z=				0.0f;	
	out_texcoord.a=				0;
}

#endif // VERTEX_SHADER


#ifdef PIXEL_SHADER
sampler2D raindrop_texture : register(s0);

float4 default_ps(
	in float4	texcoord			:	TEXCOORD0) : COLOR0
{
	float4 color;
	
//	color=	tex2D(raindrop_texture, texcoord.yx);
	asm
	{
		tfetch2D	color, texcoord.yx, raindrop_texture, UnnormalizedTextureCoords= false, MagFilter= linear, MinFilter= linear, MipFilter= linear, AnisoFilter= max4to1
	};
	
	if (particle_alpha_blend)
	{
		// convert alpha-blend -> premultiplied alpha
		color.rgb	*=	color.a;

		// tint, fade
		color.rgba *=	particle_tint.rgba;
		
		color.rgba *=	texcoord.a;
	}
	else if (texcoord.a>0)
	{
		// tint, fade
		color.rgba *=	particle_tint.rgba;
		
		// adjust to double-multiply form, transparents become 50% gray
		color.rgb=		lerp(0.5f, color.rgb, color.a * texcoord.a) / 32.0f;
	}
    else
    {
         color.rgb =    0.5f/ 32.0f;
       color.a = 0;
    }
	
	return color;
}

float4 light_volume_ps(
	in float4	texcoord			:	TEXCOORD0,
	in float3	lighting				:	TEXCOORD1
	) : COLOR0
{
	float4 color=	tex2D(raindrop_texture, texcoord.yx);
	color.rgb	*=	color.a*lighting.xyz;
	color.rgba *=	particle_tint.rgba;	
	return color;
}
#endif // PIXEL_SHADER

#endif // XENON