////#line 1 "source\rasterizer\hlsl\effects\cheap_particles_spawn.hlsl
//@generate tiny_position

#if DX_VERSION == 11
// @compute_shader
#endif

#define VERTICES_PER_PARTICLE	4
#define PARTICLE_TEXTURE_SIZE	128

#include "hlsl_constant_globals.fx"
#include "effects\cheap_particles_common.fx"

#if defined(pc) && (DX_VERSION != 11)

	void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
	float4 default_ps() : COLOR0							{ return 0.0f; }

#else // XENON

void spawn_particle(
#if DX_VERSION == 9
	in int vertex_index
#else
	in int particle_index
#endif
	)
{
#if DX_VERSION == 9
	float particle_index=				vertex_index + spawn_offset.x;
#endif

	float4x4 transform;
	float3 left;
	left=								cross(spawn_up, spawn_forward);
	transform[0]=						float4(spawn_up.xyz, 0.0f);
	transform[1]=						float4(left.xyz, 0.0f);
	transform[2]=						float4(spawn_forward.xyz, 0.0f);
	transform[3]=						float4(0.0f, 0.0f, 0.0f, 0.0f);

	// calculate random position
	float4	position_random=			generate_random(particle_index, position_texture, position_texture_transform);

	if (position_in_local_space)
	{
		position_random=					mul(position_random, transform);
	}

	// apply scale and flatten
	float3	position=					position_random.xyz * spawn_position_parameters.x;
	position=							position - spawn_forward.xyz * dot(position, spawn_forward.xyz) * spawn_position_parameters.y;

	// offset by spawn origin
	position=							position + spawn_position.xyz;

	float4	random=						generate_random(particle_index, random_texture, random_texture_transform);

	float directionality=				spawn_velocity_parameters.x + spawn_velocity_parameters.y * random.x;
	float speed=						spawn_velocity_parameters.z + spawn_velocity_parameters.w * random.y;

	float4	velocity_random=			generate_random(particle_index, velocity_texture, velocity_texture_transform);

	if (velocity_in_local_space)
	{
		velocity_random=					mul(velocity_random, transform);
	}

	float3	direction=					lerp(velocity_random.xyz, spawn_forward.xyz, directionality);
	if (spawn_velocity_normalize)
	{
		direction=						normalize(direction);
	}
	direction=							direction * speed;

	float	delta_age=					random.z	*	spawn_time_parameters.w		+	spawn_time_parameters.z;

	float4 position_and_age=			float4(position,	0.0f);
	float4 velocity_and_delta_age=		float4(direction,	delta_age);

	float	particle_type=				dot((random.w >= spawn_type_thresholds), spawn_type_constants);

	float4	physics=					get_type_data(particle_type, TYPE_DATA_PHYSICS);
	float	drag=						physics.x;
	float	gravity=					-physics.y;
	float	turbulence=					physics.z;
	float	collision_range=			physics.w;				// 0.1f world units

	// apply subframe time offset -- do update but without collisions
	{
		float	subframe_time_offset=		spawn_time_parameters.x + spawn_time_parameters.y * random.z;
		float	subframe_delta_time=		subframe_time_offset * delta_time.x;

		position_and_age.xyz		+=		velocity_and_delta_age.xyz * subframe_delta_time + float3(0, 0, gravity) * subframe_delta_time * subframe_delta_time;
		velocity_and_delta_age.z	+=		gravity * subframe_delta_time;

		position_and_age.w			+=		0.1f * subframe_delta_time;
		position_and_age.w			=		max(position_and_age.w, 0.0001f);	// we can't allow zero time, or else the sign() won't work on it and the particles will be immortal

		{
			velocity_and_delta_age.xyz	-=	velocity_and_delta_age.xyz * drag * subframe_delta_time;
		}
	}

	float angle=		frac(particle_index * 0.2736f + random.w) * spawn_position_parameters.z;
	float2 local_dx=	(frac(angle + float2(0.25f, 0.0f)) * 2 -1);

	// approximation of sin/cos,	given local_dx in the range [-1,1] representing the full 360 degrees	:		(4 - 4 * abs(local_dx)) * local_dx
	local_dx=		(spawn_position_parameters.w - spawn_position_parameters.w * abs(local_dx)) * local_dx;

	float4	particle_parameters=		float4(particle_type, spawn_position.w, local_dx);

	memexport_position_and_age(			particle_index,		position_and_age);
	memexport_velocity_and_delta_age(	particle_index,		velocity_and_delta_age);
	memexport_particle_parameters(		particle_index,		particle_parameters);
}

#if DX_VERSION == 9

#ifdef VERTEX_SHADER
void default_vs(in int vertex_index : INDEX)
{
	spawn_particle(vertex_index);
};
#endif // VERTEX_SHADER


// Dummy pixel shader, we only export to VB from VS here (manually set to NULL)
float4 default_ps() : COLOR0
{
	return 0.0f;
}

#elif DX_VERSION == 11

[numthreads(CS_CHEAP_PARTICLE_SPAWN_THREADS,1,1)]
void default_cs(in uint raw_index : SV_DispatchThreadID)
{
	if (raw_index < particle_index_range.y)
	{
		uint row_index = raw_index >> k_cheap_particle_row_shift;
		uint col_index = raw_index & k_cheap_particle_row_mask;
		s_particle_row row = cheap_particle_row_buffer[particle_index_range.x + row_index];
		g_system_index = (row.system_count >> 16) + particle_index_range.z;
		uint count = row.system_count & 0xffff;
		if (col_index < count)
		{
			spawn_particle(row.start + col_index);
		}
	}
}

#endif

#endif // XENON