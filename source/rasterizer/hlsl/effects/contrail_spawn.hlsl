/*
CONTRAIL_SPAWN.HLSL
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
11/11/2005 11:38:58 AM (davcook)

Shaders for contrail spawning
*/

#include "hlsl_constant_globals.fx"

#ifdef VERTEX_SHADER

#define MEMEXPORT_ENABLED 1

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

#include "hlsl_vertex_types.fx"
#include "effects\contrail_spawn_registers.fx"	// must come before contrail_common.fx
#include "effects\contrail_common.fx"

//This comment causes the shader compiler to be invoked for certain types
//@generate contrail

#ifndef pc
float4 contrail_main( vertex_type IN ) :POSITION
{
	s_profile_state STATE= read_profile_state(IN.index);
	int out_index= IN.address.x + IN.address.y * g_buffer_dims.x;
	write_profile_state(STATE, out_index);
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
	contrail_main(IN);
}
#endif

#endif //VERTEX_SHADER

// Should never be executed
float4 default_ps( void ) :COLOR0
{
	return float4(0,1,2,3);
}
