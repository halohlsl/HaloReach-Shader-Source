////#line 1 "source\rasterizer\hlsl\effects\cheap_particles_update.hlsl"
//@generate tiny_position

#define DROP_TEXTURE_SIZE		128
#define SPLASH_TEXTURE_SIZE		512

#define PARTICLE_TEXTURE_WIDTH		128
#define PARTICLE_TEXTURE_HEIGHT		64

//#define SPLASH_COLLISION_HALF_RANGE 0.1

#include "hlsl_constant_globals.fx"
#include "effects\cheap_particles_common.fx"

#if DX_VERSION == 11
// @compute_shader
#endif

#if defined(pc) && (DX_VERSION != 11)

	void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
	float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON

void update_particle(in int index)
{
	float particle_index= index;

	float4 position_and_age=	fetch_position_and_age(particle_index);

	if (abs(position_and_age.w) < 1.0f)
	{
		float4	velocity_and_delta_age=	fetch_velocity_and_delta_age(particle_index);
		float delta_age=				velocity_and_delta_age.w;

		float4 particle_parameters=		fetch_particle_parameters(particle_index);
		float	particle_type=			particle_parameters.x;
		float	size_scale=				1.0f;	// particle_parameters.y * (0.8f/255.0f) + 0.2f;
//		float	delta_age=				exp2(particle_parameters.z * (-4.322 / 255.0) + 1);			// designed to give us a lifetime range between [0.5, 10] seconds, with more precision at the shorter end
//		float	illumination=			exp2(particle_parameters.y * (22/255.0));					// light range between [1, 2^22], gives us about 6.16% brightness steps

		float4	physics=				get_type_data(particle_type, TYPE_DATA_PHYSICS);
		float	drag=					physics.x;
		float	gravity=				-physics.y;
		float	turbulence=				physics.z;
		float	collision_range=		physics.w;				// 0.1f world units

		position_and_age.w		+=		sign(position_and_age.w) * delta_age * delta_time;

//		if (length(velocity_and_delta_age.xyz) > 0.1f)			//  || (abs(velocity_and_delta_age.w) > 0.05f)		// attempts to stop bobbling motion when the particle is close to at-rest
		if (position_and_age.w >= 0.0f)							// 'at rest' is determined by sign of age
		{
			// not 'at rest'
			float4 turb_sample=				turbulence * generate_random(particle_index, velocity_texture, turbulence_transform);

			position_and_age.xyz	+=		(velocity_and_delta_age.xyz + turb_sample) * delta_time.x + float3(0, 0, gravity) * delta_time.x * delta_time.x;
			velocity_and_delta_age.xyz	+=	(float3(0, 0, gravity) - velocity_and_delta_age.xyz * drag) * delta_time.x;
		}

		{
			// check depth buffer
			float4 projected_position=	float4(position_and_age.xyz, 1.0f);
			projected_position=			mul(projected_position, View_Projection);
			projected_position.xyz	/=	projected_position.w;									// [-1, 1]
			projected_position.xy=		projected_position.xy * float2(0.5f, -0.5f) + 0.5f;		// [0, 1]		###ctchou $TODO can build this into a modified version of View_Projection above

			float2 outside=	projected_position.xy - saturate(projected_position.xy);			// 0,0 if the point is inside [0,1] screen bounds
			if (dot(outside, outside) == 0.0f)
			{
				float4 depth_value;
#ifdef xenon
				asm
				{
					tfetch2D	depth_value,	projected_position.xy,	collision_depth_buffer,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false, UseRegisterGradients= false
				};
#else
				depth_value = collision_depth_buffer.t.SampleLevel(collision_depth_buffer.s, projected_position.xy, 0);
#endif
				float scene_depth= 1.0f - depth_value.x;
				scene_depth= 1.0f / (collision_depth_constants.x + scene_depth * collision_depth_constants.y);		// convert to real depth

				if (position_and_age.w >= 0.0f)
				{
					if (abs(projected_position.w - scene_depth - collision_range) < collision_range)
					{
						// move particle to the collision location
						float3	camera_to_drop=		position_and_age.xyz - Camera_Position;
						float	reprojection_scale=	scene_depth / dot(camera_to_drop, -Camera_Backward);
						camera_to_drop	*=			reprojection_scale;
						position_and_age.xyz=		camera_to_drop	+	Camera_Position;

						float4	normal;
#ifdef xenon
						asm
						{
							tfetch2D	normal,		projected_position.xy,	collision_normal_buffer,	UnnormalizedTextureCoords= false,	MagFilter= point,	MinFilter= point,	MipFilter= point,	AnisoFilter= disabled,	UseComputedLOD= false, UseRegisterGradients= false
						};
#else
						normal = collision_normal_buffer.t.SampleLevel(collision_normal_buffer.s, projected_position.xy, 0);
#endif

						if (dot(normal, velocity_and_delta_age.xyz) > 0.1f)
						{
							// particle is heading out of the ground, kill it (so it doesn't appear magically)
							position_and_age.w=	2.0f;
						}
						else
						{
							// collision detected
							float4	collision=				get_type_data(particle_type, TYPE_DATA_COLLISION);
							float	collision_bounce=		collision.y;
							float	collision_death=		collision.z;
							float	collision_type=			collision.w;

							// reflect particle velocity around normal to bounce
							velocity_and_delta_age.xyz=		collision_bounce * reflect(velocity_and_delta_age.xyz, normal);

							// move particle forward along reflected velocity vector a bit.
							position_and_age.xyz	+=		velocity_and_delta_age.xyz * delta_time.x * 0.5f;

							// check if 'at rest'
							if (length(velocity_and_delta_age.xyz) < 0.2f)
							{
								position_and_age.w=	-position_and_age.w;
							}

							// update type on collision
							particle_parameters.x=		collision_type;
							memexport_particle_parameters(particle_index, particle_parameters);
						}
					}
				}
				else
				{
					// at rest -- check if remaining at rest
					if (projected_position.w - scene_depth < -0.03f)
					{
						// not colliding anymore!   reset at-rest state
						position_and_age.w=	-position_and_age.w;
					}
				}
			}
		}

		memexport_position_and_age(particle_index, position_and_age);
		memexport_velocity_and_delta_age(particle_index, velocity_and_delta_age);
	}
}

#if DX_VERSION == 9

#ifdef VERTEX_SHADER

void default_vs(in int index	: INDEX)
{
	update_particle(index);
}

#endif // VERTEX_SHADER

#ifdef PIXEL_SHADER
float4 default_ps(): COLOR0
{
	return 0.0f;
}
#endif // PIXEL_SHADER

#elif DX_VERSION == 11

[numthreads(CS_CHEAP_PARTICLE_UPDATE_THREADS,1,1)]
void default_cs(in uint raw_index : SV_DispatchThreadID)
{
	uint index = raw_index + particle_index_range.x;
	if (index < particle_index_range.y)
	{
		update_particle(raw_index);
	}
}

#endif

#endif // XENON