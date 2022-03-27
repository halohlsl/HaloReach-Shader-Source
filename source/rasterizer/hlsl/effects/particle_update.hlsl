/*
PARTICLE_UPDATE.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for particle physics, state updates
*/

#define PARTICLE_WRITE 1

#include "hlsl_constant_globals.fx"


// rain particles visibility occlusion map
VERTEX_CONSTANT (sampler, sampler_weather_occlusion, s1);	//	k_vs_sampler_weather_occlusion in hlsl_constant_oneshot.h
VERTEX_CONSTANT (sampler, sampler_turbulence, s2);			//	k_vs_sampler_weather_occlusion in hlsl_constant_oneshot.h


#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);
#define UPDATE_CONSTANT(type, name, register_index) VERTEX_CONSTANT(type, name, register_index)

#ifdef VERTEX_SHADER
#include "hlsl_vertex_types.fx"
#include "effects\particle_update_registers.fx"	// must come before particle_common.fx
#include "effects\particle_common.fx"


//This comment causes the shader compiler to be invoked for certain types
//@generate particle

typedef s_particle_vertex s_particle_in;
typedef void s_particle_out;

#ifndef pc
struct s_update_state
{
	float m_gravity;
	float m_air_friction;
	float m_rotational_friction;
};
extern s_update_state g_update_state;

// Assumes position is above the tile in world space.
void clamp_to_tile(inout float3 position)
{
#ifdef CLAMP_IN_WORLD_Z_DIRECTION	// This leads to particle clumping
	float3 tile_pos= frac(mul(float4(position, 1.0f), world_to_tile));
	float3 tile_z= mul(float4(0.0f, 0.0f, 1.0f, 0.0f), world_to_tile);
	
	// Clamp down to the three positive planes.  Should have no effect on things already below.
	float3 lift_to_pos_planes= (1.0f - tile_pos)/tile_z;
	float min_lift= min(lift_to_pos_planes.x, lift_to_pos_planes.z);	// only need y if there's roll; otherwise this is divide-by-zero
	tile_pos+= tile_z * min_lift;
	
	position= mul(float4(tile_pos, 1.0f), tile_to_world);
#else	//if CLAMP_IN_TILE_Z_DIRECTION
	position= mul(float4(frac(mul(float4(position, 1.0f), world_to_tile)).xy, 1.0f, 1.0f), tile_to_world);
#endif
}

void wrap_to_tile(inout float3 position)
{
	// This code compiles to 9 ALU instructions ###ctchou $TODO why 9???  shouldn't it be 3 ALUs?  maybe even less if it scalar pairs all the individual channels of the frac
	position= mul(float4(frac(mul(float4(position, 1.0f), world_to_tile)), 1.0f), tile_to_world);
}

// Used to recycle particles to near the camera
void update_particle_state_tiling(inout s_particle_state STATE)
{
	if (tiled)
	{
		wrap_to_tile(STATE.m_position);
	}
}

#define HIDE_OCCLUDED_PARTICLES
void update_particle_state_collision(inout s_particle_state STATE)
{
	// This code compiles to 2 sequencer blocks and 9 ALU instructions.  We can get to 7 ALU by putting the 1.0f and 2.0f below into
	// the matrix
/*	if (collision)					// removed (leaving here for reference in case we want to eventually use the new weather occlusion system)
	{
		float3 weather_space_pos= mul(float4(STATE.m_position, 1.0f), world_to_occlusion).xyz;
		float occlusion_z= tex2Dlod(sampler_weather_occlusion, float4(weather_space_pos.xy, 0, 0)).x;
		if (occlusion_z< weather_space_pos.z)
		{
			// particle is occluded by geometry...
#if defined(TINT_OCCLUDED_PARTICLES)
			STATE.m_color= float4(1.0f, 0.0f, 0.0f, 1.0f);	// Make particle easily visible for debugging
#elif defined(KILL_OCCLUDED_PARTICLES)
			STATE.m_age= 1.0f;	// Kill particle
#elif defined(HIDE_OCCLUDED_PARTICLES)
			STATE.m_color.w= 0.0f;	// These get killed in the render, but are allowed to continue in the update until they tile
#else	//if defined(ATTACH_OCCLUDED_PARTICLES)
			weather_space_pos.z= occlusion_z;
			STATE.m_position= mul(float4(weather_space_pos, 1.0f), occlusion_to_world).xyz;
			STATE.m_velocity= float3(0.0f, 0.0f, -0.001f);
			if (!STATE.m_collided)
			{
				STATE.m_age= 0.0f;
				STATE.m_collided= true;
			}
#endif
		}
	}
*/
}

void update_particle_looping(inout s_particle_state STATE)
{
#if defined(ATTACH_OCCLUDED_PARTICLES)
	if (looping)
	{
		if (STATE.m_age>= 1.0f)
		{
			STATE.m_age= frac(STATE.m_age);
			if (STATE.m_collided)
			{
				clamp_to_tile(STATE.m_position);
				STATE.m_collided= false;
			}
		}
	}
#endif
}

void update_particle_state(inout s_particle_state STATE)
{
	// This is a hack to allow one frame of no updating after spawn.
	float dt= (STATE.m_size>= 0.0f) ? delta_time : 0.0f;

	// Update particle life
	STATE.m_age+= STATE.m_inverse_lifespan * dt;

	float pre_evaluated_scalar[_index_max]= preevaluate_particle_functions(STATE);

	if (STATE.m_age< 1.0f)
	{
		// Update particle pos
		STATE.m_position.xyz+= STATE.m_velocity.xyz * dt;
		
		if (turbulence)
		{
			float4 turbulence_texcoord;
			turbulence_texcoord.xy=	float2(STATE.m_birth_time, STATE.m_random2.x) * turbulence_xform.xy + turbulence_xform.zw;
			turbulence_texcoord.zw=	0.0f;
			STATE.m_position.xyz += (tex2Dlod(sampler_turbulence, turbulence_texcoord).xyz - 0.5f) * pre_evaluated_scalar[_index_emitter_movement_turbulence] * dt;
		}

		// Update velocity (saturate is so friction can't cause reverse of direction)
		STATE.m_velocity+= particle_map_to_vector3d_range(_index_particle_self_acceleration, pre_evaluated_scalar[_index_particle_self_acceleration])
			* dt;
		STATE.m_velocity.z-= g_update_state.m_gravity * dt;
		STATE.m_velocity.xyz-= saturate(g_update_state.m_air_friction * dt) * STATE.m_velocity.xyz;
		
		// Update rotational velocity (saturate is so friction can't cause reverse of direction)
		STATE.m_rotational_velocity-= saturate(g_update_state.m_rotational_friction * dt) * STATE.m_rotational_velocity;
		
		// Update rotation (only stored as [0,1], and "frac" is necessary to avoid clamping)
		STATE.m_physical_rotation= 
			frac(STATE.m_physical_rotation + STATE.m_rotational_velocity * dt);
		STATE.m_manual_rotation= frac(pre_evaluated_scalar[_index_particle_rotation]);
		
		// Update frame animation (only stored as [0,1], and "frac" is necessary to avoid clamping)
		STATE.m_animated_frame= frac(STATE.m_animated_frame + STATE.m_frame_velocity * dt);
		STATE.m_manual_frame= frac(pre_evaluated_scalar[_index_particle_frame]);
		
		// Compute color (will be clamped [0,1] and compressed to 8-bit upon export)
		STATE.m_color.xyz= particle_map_to_color_range(_index_emitter_tint, pre_evaluated_scalar[_index_emitter_tint])
			* particle_map_to_color_range(_index_particle_color, pre_evaluated_scalar[_index_particle_color]);
		STATE.m_color.w= pre_evaluated_scalar[_index_emitter_alpha] 
			* pre_evaluated_scalar[_index_particle_alpha];
			
		// Update other particle state
		STATE.m_size= pre_evaluated_scalar[_index_emitter_size] * pre_evaluated_scalar[_index_particle_scale];
		STATE.m_aspect= pre_evaluated_scalar[_index_particle_aspect];
		STATE.m_intensity= pre_evaluated_scalar[_index_particle_intensity];
		STATE.m_black_point= saturate(pre_evaluated_scalar[_index_particle_black_point])*_1_minus_epsilon; // avoid wrap
		STATE.m_palette_v= saturate(pre_evaluated_scalar[_index_particle_palette])*_1_minus_epsilon;// avoid wrap
	}
	else
	{
		// Particle death, kill pixel
		// Can't do this for EDRAM, since anything we write gets resolved back
		// For MemExport, should skip the writeback in this case.
	}
}

s_particle_out particle_main( s_particle_in IN )
{
	s_particle_state STATE;
	s_particle_out OUT;

	STATE= read_particle_state(IN.index);

	update_particle_state(STATE);
	update_particle_state_tiling(STATE);
	update_particle_state_collision(STATE);
	update_particle_looping(STATE);
	
	//return 
	write_particle_state(STATE, IN.index);
}
#endif	// #ifndef pc

// For EDRAM method, the main work must go in the pixel shader, since only 
// pixel shaders can write to EDRAM.
// For the MemExport method, we don't need a pixel shader at all.
// This is signalled by a "void" return type or "multipass" config?

#ifdef pc
float4 default_vs( vertex_type IN ) :POSITION
{
	return float4(1, 2, 3, 4);
}
#else
void default_vs( vertex_type IN )
{
//	asm {
//		config VsExportMode=multipass   // export only shader
//	};
	particle_main(IN);
}
#endif

#else	//#ifdef VERTEX_SHADER
// Should never be executed
float4 default_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}
#endif
