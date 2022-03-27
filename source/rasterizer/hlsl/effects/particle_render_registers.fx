/*
PARTICLE_RENDER_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
12/5/2005 11:50:57 AM (davcook)
	
*/

VERTEX_CONSTANT(float4, hidden_from_compiler, 32)	// the compiler will complain if these are literals
VERTEX_CONSTANT(float3x4, local_to_world, 33)	// local_to_world[0] is a column not a row!

// These corresponding to global externs in the particle render_method_definition
PIXEL_CONSTANT(float4, depth_transform, 202)
