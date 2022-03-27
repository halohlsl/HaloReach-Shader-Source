////#line 1 "source\rasterizer\hlsl\effects\cheap_particles_initialize.hlsl
//@generate tiny_position

#include "hlsl_constant_globals.fx"
#include "effects\cheap_particles_common.fx"

#ifdef pc
	void default_vs(out float4 out_position : POSITION)		{ out_position= 0.0f; }
	float4 default_ps() : COLOR0							{ return 0.0f; }
#else // XENON


#ifdef VERTEX_SHADER
void default_vs(
	in int vertex_index			: INDEX)
{
	float particle_index=			vertex_index;

	float4 position_and_age=		float4(0, 0, 0, 2 );		//	Proper values:  (NaN.xyz, -1); 
	float4 velocity_and_delta_age=  float4(0, 1, 0, 0 );		//					(NaN);
	float4 particle_parameters=		float4(0, 0, 0, 0 );		//	NaN);
	
	memexport_position_and_age(			particle_index,		position_and_age);
	memexport_velocity_and_delta_age(	particle_index,		velocity_and_delta_age);
	memexport_particle_parameters(		particle_index,		particle_parameters);
};
#endif // VERTEX_SHADER


// Dummy pixel shader, we only export to VB from VS here (manually set to NULL)
float4 default_ps() : COLOR0							
{ 
	return 0.0f; 
}


#endif // XENON