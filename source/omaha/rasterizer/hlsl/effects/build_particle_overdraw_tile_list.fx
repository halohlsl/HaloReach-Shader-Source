
#include "hlsl_constant_globals.fx"
#include "effects\build_particle_overdraw_tile_list_registers.fx"
#include "shared\read_cmask.fx"

#ifdef durango

//@compute_shader
//@entry default
//@entry albedo
//@entry static_sh
//@entry shadow_apply

void build_particle_overdraw_tile_list(in uint index, in bool is_xboxone_x, in bool build_partial_list)
{
	if (index < max_index)
	{
		uint2 block_coord = uint2(index % cmask_width, index / cmask_width);

		uint cmask = 0;
		uint not_cmask = 0;

		uint2 base_coord = block_coord * PARTICLE_OVERDRAW_BLOCK_SIZE;
		for (uint y = 0; y < PARTICLE_OVERDRAW_BLOCK_SIZE; y++)
		{
			uint2 coord;
			coord.y = base_coord.y + y;

			for (uint x = 0; x < PARTICLE_OVERDRAW_BLOCK_SIZE; x++)
			{
				coord.x = base_coord.x + x;

				uint block_cmask = read_cmask(cmask_buffer, coord, cmask_pitch, is_xboxone_x);
				cmask |= block_cmask;
				not_cmask |= (block_cmask ^ 0xf);
			}
		}

		if (cmask)
		{
			if (build_partial_list && not_cmask)
			{
				partial_tile_buffer.Append(block_coord);
			} else
			{
				full_tile_buffer.Append(block_coord);
			}
		}
	}
}

[numthreads(CS_BUILD_PARTICLE_OVERDRAW_TILE_LIST_THREADS, 1, 1)]
void default_cs(in uint index : SV_DispatchThreadID)
{
	build_particle_overdraw_tile_list(index, false, false);
}

[numthreads(CS_BUILD_PARTICLE_OVERDRAW_TILE_LIST_THREADS, 1, 1)]
void albedo_cs(in uint index : SV_DispatchThreadID)
{
	build_particle_overdraw_tile_list(index, true, false);
}

[numthreads(CS_BUILD_PARTICLE_OVERDRAW_TILE_LIST_THREADS, 1, 1)]
void static_sh_cs(in uint index : SV_DispatchThreadID)
{
	build_particle_overdraw_tile_list(index, false, true);
}

[numthreads(CS_BUILD_PARTICLE_OVERDRAW_TILE_LIST_THREADS, 1, 1)]
void shadow_apply_cs(in uint index : SV_DispatchThreadID)
{
	build_particle_overdraw_tile_list(index, true, true);
}


#endif
