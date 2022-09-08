#if DX_VERSION == 11

CBUFFER_BEGIN(BuildParticleOverdrawTileList)
	CBUFFER_CONST(BuildParticleOverdrawTileList,		uint,		max_index,		k_cs_build_particle_overdraw_tile_list_max_index)
	CBUFFER_CONST(BuildParticleOverdrawTileList,		uint,		cmask_width,	k_cs_build_particle_overdraw_tile_list_cmask_width)
	CBUFFER_CONST(BuildParticleOverdrawTileList,		uint,		cmask_pitch,	k_cs_build_particle_overdraw_tile_list_cmask_pitch)
CBUFFER_END


BUFFER(cmask_buffer, 							k_cs_build_particle_overdraw_tile_list_cmask_buffer, 			uint, 	0)
APPEND_STRUCTURED_BUFFER(full_tile_buffer,		k_cs_build_particle_overdraw_tile_list_full_tile_buffer, 		uint2, 	0)
APPEND_STRUCTURED_BUFFER(partial_tile_buffer,	k_cs_build_particle_overdraw_tile_list_partial_tile_buffer, 	uint2, 	1)

#define CS_BUILD_PARTICLE_OVERDRAW_TILE_LIST_THREADS 64
#define PARTICLE_OVERDRAW_BLOCK_SIZE 4

#endif
