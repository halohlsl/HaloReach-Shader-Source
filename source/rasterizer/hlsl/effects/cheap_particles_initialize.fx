////#line 1 "source\rasterizer\hlsl\effects\cheap_particles_initialize.hlsl
//@generate tiny_position

#include "hlsl_constant_globals.fx"
#include "effects\cheap_particles_common.fx"

#if DX_VERSION == 11
// @compute_shader
#endif

#if defined(pc) && (DX_VERSION != 11)
	void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
	float4 default_ps() : COLOR0							{ return 0.0f; }
#else // XENON

void initialize_particle(in int vertex_index)
{
	float particle_index=			vertex_index;

	float4 position_and_age=		float4(0, 0, 0, 2 );		//	Proper values:  (NaN.xyz, -1);
	float4 velocity_and_delta_age=  float4(0, 1, 0, 0 );		//					(NaN);
	float4 particle_parameters=		float4(0, 0, 0, 0 );		//	NaN);

	memexport_position_and_age(			particle_index,		position_and_age);
	memexport_velocity_and_delta_age(	particle_index,		velocity_and_delta_age);
	memexport_particle_parameters(		particle_index,		particle_parameters);
}

#if DX_VERSION == 9

#ifdef VERTEX_SHADER
void default_vs(
	in int vertex_index			: INDEX)
{
	initialize_particle(vertex_index);
};
#endif // VERTEX_SHADER


// Dummy pixel shader, we only export to VB from VS here (manually set to NULL)
float4 default_ps() : COLOR0
{
	return 0.0f;
}

#elif DX_VERSION == 11

[numthreads(CS_CHEAP_PARTICLE_INIT_THREADS,1,1)]
void default_cs(in uint raw_index : SV_DispatchThreadID)
{
	uint index = raw_index + particle_index_range.x;
	if (index < particle_index_range.y)
	{
		initialize_particle(index);
	}
}

#endif

#endif // XENON