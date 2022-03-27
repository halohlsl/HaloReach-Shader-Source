/*
PARTICLE_SPAWN.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for particle spawning
*/

#define PARTICLE_WRITE 1

#include "hlsl_constant_globals.fx"

#define UPDATE_CONSTANT(type, name, register_index) VERTEX_CONSTANT(type, name, register_index)
#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(c##register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(c##register_index);
#endif
#define SAMPLER_CONSTANT(name, register_index)	sampler2D name : register(s##register_index);

#ifdef VERTEX_SHADER
#include "hlsl_vertex_types.fx"
#include "effects\particle_spawn_registers.fx"	// must come before particle_common.fx
#include "effects\particle_common.fx"

//This comment causes the shader compiler to be invoked for certain types
//@generate particle

#ifndef pc
float4 particle_main( vertex_type IN ) :POSITION
{
	s_particle_state STATE= read_particle_state(IN.index);
	static int2 dims= int2(16, 448);	// Make this linked to .cpp
	int out_index= IN.address.x + IN.address.y * dims.x;
	write_particle_state(STATE, out_index);
}
#endif

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