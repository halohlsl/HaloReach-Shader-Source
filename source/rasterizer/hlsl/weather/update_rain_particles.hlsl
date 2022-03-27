////#line 1 "source\rasterizer\hlsl\weather\update_rain_particles.hlsl"
//@generate tiny_position

//@entry default
//@entry albedo


#define DROP_TEXTURE_SIZE		128
#define SPLASH_TEXTURE_SIZE		512

#include "hlsl_constant_globals.fx"

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#include "weather\rain_registers.h"


#ifdef pc

void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 default_ps() : COLOR0							{ return 0.0f; }
void albedo_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
float4 albedo_ps() : COLOR0								{ return 0.0f; }

#else // XENON


#ifdef VERTEX_SHADER
void default_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION)
{
	float2		verts[4]=
	{
		float2(-1.0f,-1.0f),
		float2( 1.0f,-1.0f),
		float2( 1.0f, 1.0f),
		float2(-1.0f, 1.0f),
	};

	out_position.xy=	verts[index];
	out_position.zw=	1.0f;
}
void albedo_vs(
	in int index						:	INDEX,
	out float4	out_position			:	POSITION)
{
	default_vs(index, out_position);
}
#endif // VERTEX_SHADER


sampler2D	drop_texture : register(s0);
sampler2D	shadow_texture : register(s1);
sampler2D	screen_normal_texture : register(s2);


#ifdef PIXEL_SHADER
#ifndef pc
//[maxtempreg(5)]
#endif // pc
float4 default_ps(
	in float2	drop_coord	:	VPOS) : COLOR0
{
	float4 drop_data;
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};

	float alive= drop_data.y;
	float3 drop_position_cube=		float3(drop_coord / DROP_TEXTURE_SIZE, drop_data.x) + virtual_offset.xyz;
	drop_position_cube=				drop_position_cube - floor(drop_position_cube);
	float3 drop_position_world=		center.xyz + center.w * (drop_position_cube - 0.5f);			// ###ctchou $TODO optimize by putting the -0.5 into center.xyz

	
	// check shadowing
	float2 shadow_texcoord=		drop_position_world.xy * shadow_proj.xy + shadow_proj.zw;
	float4 shadow;
	asm
	{
		tfetch2D	shadow,	shadow_texcoord.xy,	shadow_texture,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false,  UseRegisterGradients=false
	};
	float occluder_z= shadow.x * shadow_depth.x + shadow_depth.y;
	

	if (alive > 0.0f)
	{
		if (drop_position_world.z < occluder_z)
		{
			// not visible
			alive= 0.0f;
		}
		else	
		{
			// check depth buffer
			float4 projected_position=	float4(drop_position_world, 1.0f);
			projected_position=			mul(projected_position, transpose(view_projection));
			projected_position.xyz	/=	projected_position.w;									// [-1, 1]	
			projected_position.xy=		projected_position.xy * float2(0.5f, -0.5f) + 0.5f;		// [0, 1]
			
			float2 outside=	projected_position.xy - saturate(projected_position.xy);			// 0,0 if the point is inside [0,1] screen bounds
			if (dot(outside, outside) == 0.0f)
			{
				float4 depth_value;
				asm
				{
					tfetch2D	depth_value,	projected_position.xy,	depth_buffer,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
				};
				
				float scene_depth= 1.0f - depth_value.x;
				scene_depth= 1.0f / (rain_depth_constants.x + scene_depth * rain_depth_constants.y);		// convert to real depth
				
				if (abs(projected_position.w - scene_depth - SPLASH_COLLISION_HALF_RANGE) < SPLASH_COLLISION_HALF_RANGE)
				{
					float4 normal_value;
					asm
					{
						tfetch2D	normal_value,	projected_position.xy,	screen_normal_texture,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
					};
				
					if (normal_value.z > 0.2f)
					{
						// collision -- generate splash
						float3 camera_to_drop=		drop_position_world - camera_position;
						camera_to_drop	*=			scene_depth / dot(camera_to_drop, camera_forward);
						float4 result=	float4(camera_to_drop + camera_position, 0.0f);
						result.z += SPLASH_HEIGHT;
									
						float pixel_index= saturate(projected_position.x) * (SPLASH_TEXTURE_SIZE - 1);
						
						const float4 k_offset_const= { 0, 1, 0, 0 };
						asm {
							alloc export=1
							mad eA, pixel_index, k_offset_const, export_stream_constant
							mov eM0, result
						};
					}
					
					// collision -- kill raindrop
					alive= 0;
				}
			}
		}
	}
	else
	{
		// ###ctchou $TODO -- this should check whether the drop is inside an update region -- i.e. outside the overlapping region of the previous rain volume.
		if ((drop_position_cube.z > 0.8f) && (drop_position_world.z > occluder_z))
		{
			alive= 1.0f;
		}
	}
	
	return float4(drop_data.x, alive, alive, alive);
}


float4 albedo_ps(
	in float2	drop_coord	:	VPOS) : COLOR0
{
	// no collision update
	float4 drop_data;
	asm
	{
		tfetch2D	drop_data,	drop_coord.xy,	drop_texture,	UnnormalizedTextureCoords= true,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled
	};

	float alive= 1.0f;
	return float4(drop_data.x, alive, alive, alive);
}

#endif // PIXEL_SHADER

#endif // XENON