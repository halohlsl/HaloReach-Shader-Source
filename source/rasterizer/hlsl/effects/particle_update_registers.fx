/*
PARTICLE_UPDATE_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
12/5/2005 11:50:57 AM (davcook)
	
*/

VERTEX_CONSTANT(float, delta_time, 21)
VERTEX_CONSTANT(float4, hidden_from_compiler, 22)	// the compiler will complain if these are literals
VERTEX_CONSTANT(float4x3, tile_to_world, 23)	//= {float3x3(Camera_Forward, Camera_Left, Camera_Up) * tile_size, Camera_Position};
VERTEX_CONSTANT(float4x3, world_to_tile, 26)	//= {transpose(float3x3(Camera_Forward, Camera_Left, Camera_Up) * inverse_tile_size), -Camera_Position};
VERTEX_CONSTANT(float4x3, occlusion_to_world, 29)
VERTEX_CONSTANT(float4x3, world_to_occlusion, 32)
VERTEX_CONSTANT(float4, turbulence_xform, 36)

BOOL_CONSTANT(tiled, 20)
// BOOL_CONSTANT(collision, 21)						// removed (leaving here for reference in case we want to eventually use the new weather occlusion system)
BOOL_CONSTANT(turbulence, 22)
