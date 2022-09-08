//#line 2 "source\rasterizer\hlsl\durango_downsample_depth.hlsl"

#include "hlsl_constant_globals.fx"
#include "postprocess\durango_downsample_depth_registers.fx"

#ifdef durango

//@compute_shader

// Adapted from the MiniEngine sample, our depth buffer is always fully decompressed
// by this point so we don't need to worry about decompressing it.

groupshared float gs_depths[16 * 16];

// the coord for the given micro tile index
uint2 pixel_coord_from_linear_index(uint element)
{
    // This is some tricky bit twiddling.  Too bad it doesn't outperform a table
    // lookup.  :-(
    element = (element * 0x808101 & 0x10051005) + 0x10001;
    element |= element >> 9;
    return uint2( __XB_UBFE(3, 1, element), __XB_UBFE(3, 17, element) );

    //return uint2(
    //	element >> 0 & 0x1 | element >> 1 & 0x2 | element >> 2 & 0x4,
    //	element >> 1 & 0x1 | element >> 2 & 0x2 | element >> 3 & 0x4);
}

uint2 swizzle_linear_index(uint element)
{
    const uint2 lookup[64] =
    {
        pixel_coord_from_linear_index(8 * 0 + 0),
        pixel_coord_from_linear_index(8 * 0 + 1),
        pixel_coord_from_linear_index(8 * 0 + 2),
        pixel_coord_from_linear_index(8 * 0 + 3),
        pixel_coord_from_linear_index(8 * 0 + 4),
        pixel_coord_from_linear_index(8 * 0 + 5),
        pixel_coord_from_linear_index(8 * 0 + 6),
        pixel_coord_from_linear_index(8 * 0 + 7),

        pixel_coord_from_linear_index(8 * 1 + 0),
        pixel_coord_from_linear_index(8 * 1 + 1),
        pixel_coord_from_linear_index(8 * 1 + 2),
        pixel_coord_from_linear_index(8 * 1 + 3),
        pixel_coord_from_linear_index(8 * 1 + 4),
        pixel_coord_from_linear_index(8 * 1 + 5),
        pixel_coord_from_linear_index(8 * 1 + 6),
        pixel_coord_from_linear_index(8 * 1 + 7),

        pixel_coord_from_linear_index(8 * 2 + 0),
        pixel_coord_from_linear_index(8 * 2 + 1),
        pixel_coord_from_linear_index(8 * 2 + 2),
        pixel_coord_from_linear_index(8 * 2 + 3),
        pixel_coord_from_linear_index(8 * 2 + 4),
        pixel_coord_from_linear_index(8 * 2 + 5),
        pixel_coord_from_linear_index(8 * 2 + 6),
        pixel_coord_from_linear_index(8 * 2 + 7),

        pixel_coord_from_linear_index(8 * 3 + 0),
        pixel_coord_from_linear_index(8 * 3 + 1),
        pixel_coord_from_linear_index(8 * 3 + 2),
        pixel_coord_from_linear_index(8 * 3 + 3),
        pixel_coord_from_linear_index(8 * 3 + 4),
        pixel_coord_from_linear_index(8 * 3 + 5),
        pixel_coord_from_linear_index(8 * 3 + 6),
        pixel_coord_from_linear_index(8 * 3 + 7),

        pixel_coord_from_linear_index(8 * 4 + 0),
        pixel_coord_from_linear_index(8 * 4 + 1),
        pixel_coord_from_linear_index(8 * 4 + 2),
        pixel_coord_from_linear_index(8 * 4 + 3),
        pixel_coord_from_linear_index(8 * 4 + 4),
        pixel_coord_from_linear_index(8 * 4 + 5),
        pixel_coord_from_linear_index(8 * 4 + 6),
        pixel_coord_from_linear_index(8 * 4 + 7),

        pixel_coord_from_linear_index(8 * 5 + 0),
        pixel_coord_from_linear_index(8 * 5 + 1),
        pixel_coord_from_linear_index(8 * 5 + 2),
        pixel_coord_from_linear_index(8 * 5 + 3),
        pixel_coord_from_linear_index(8 * 5 + 4),
        pixel_coord_from_linear_index(8 * 5 + 5),
        pixel_coord_from_linear_index(8 * 5 + 6),
        pixel_coord_from_linear_index(8 * 5 + 7),

        pixel_coord_from_linear_index(8 * 6 + 0),
        pixel_coord_from_linear_index(8 * 6 + 1),
        pixel_coord_from_linear_index(8 * 6 + 2),
        pixel_coord_from_linear_index(8 * 6 + 3),
        pixel_coord_from_linear_index(8 * 6 + 4),
        pixel_coord_from_linear_index(8 * 6 + 5),
        pixel_coord_from_linear_index(8 * 6 + 6),
        pixel_coord_from_linear_index(8 * 6 + 7),

        pixel_coord_from_linear_index(8 * 7 + 0),
        pixel_coord_from_linear_index(8 * 7 + 1),
        pixel_coord_from_linear_index(8 * 7 + 2),
        pixel_coord_from_linear_index(8 * 7 + 3),
        pixel_coord_from_linear_index(8 * 7 + 4),
        pixel_coord_from_linear_index(8 * 7 + 5),
        pixel_coord_from_linear_index(8 * 7 + 6),
        pixel_coord_from_linear_index(8 * 7 + 7),
    };

    return lookup[element];
}

// Only P4_16x16 (Durango) and P8_32x32_16x16 (Scorpio) are currently supported.  Each is indicated
// by the pipe count (4 or 8) in the htile_info header.
uint get_htile_address(uint2 tile_coord, uint htile_info)
{
    // Unpack the htile_info descriptor passed in by the application
    const uint2 num_tiles = uint2(htile_info, htile_info >> 12) & 0xFFF;
    const uint pipe_count = (htile_info >> 24) & 0x7F;
    const bool linear_addressing = (htile_info >> 31) == 1;

    // Dimensions of the macro tile for non-linear mode.  (In units of tiles, not pixels.)
    uint macro_tile_width = 64;
    uint macro_tile_height = 8 * pipe_count;

    uint tile_y0 = tile_coord.y & 1;
    uint time_x1 = (tile_coord.x >> 1) & 1;
    uint element_index = (time_x1 ^ tile_y0) | time_x1 << 1;
    uint element_index_bits = 2;

    uint pipe = (tile_coord.x ^ tile_coord.y ^ time_x1) & (pipe_count - 1);
    uint pipe_bits = firstbitlow(pipe_count);
    uint micro_right_shift = element_index_bits + pipe_bits - 4;

    // tiles_per_pipe = macro_tile_width * macro_tile_height / pipe_count
    const uint tiles_per_pipe = 512;

    const uint macro_tile_count_x = num_tiles.x / macro_tile_width; // clPitch
    const uint macro_tile_count_y = num_tiles.y / macro_tile_height;

    const uint slice_pitch = num_tiles.x * num_tiles.y / pipe_count;

    // for 2D array and 3D textures (including cube maps)
    uint tile_slice = 0; // tileZ
    uint slice_offset = slice_pitch * tile_slice;

    // macro tile location
    uint macro_x = tile_coord.x / macro_tile_width;
    uint macro_y = tile_coord.y / macro_tile_height;
    uint macro_offset = linear_addressing ? 0 : (macro_x + macro_tile_count_x * macro_y) * tiles_per_pipe;

    // micro (4x4 tile) tiling
    uint micro_x = (linear_addressing ? tile_coord.x : (tile_coord.x % macro_tile_width)) / 4;
    uint micro_y = (linear_addressing ? tile_coord.y : (tile_coord.y % macro_tile_height)) / 4;
    uint micro_pitch = (linear_addressing ? num_tiles.x : macro_tile_width) / 4;
    uint micro_offset = ((micro_x + micro_y * micro_pitch) >> micro_right_shift) << element_index_bits | element_index;

    uint tile_index = slice_offset + macro_offset + micro_offset;

    // Each element accessed by a tile index is four bytes.  So address offset is 4 * tile_index.
    uint tile_byte_offset = tile_index << 2;

    // The pipe value gets inserted into the tile_byte_offset at bit 8
    return (tile_byte_offset & ~0xff) << pipe_bits | (pipe << 8) | (tile_byte_offset & 0xff);
}

float read_depth(uint2 tile, uint2 local_coord)
{
	uint2 st = (tile << 3) | local_coord;
	return source_depth_texture[st];
}

[numthreads(8, 8, 1)]
void default_cs(
	uint3 group_id : SV_GroupID,
	uint group_index : SV_GroupIndex,
	uint3 group_thread_id : SV_GroupThreadID)
{
	uint2 pixel_coord = swizzle_linear_index(group_index);
	uint2 tile1 = group_id.xy << 1;

	uint write_index = pixel_coord.x + (pixel_coord.y * 16);

	gs_depths[write_index + 0] = read_depth(tile1 | uint2(0, 0), pixel_coord);
	gs_depths[write_index + 8] = read_depth(tile1 | uint2(1, 0), pixel_coord);
	gs_depths[write_index + 128] = read_depth(tile1 | uint2(0, 1), pixel_coord);
	gs_depths[write_index + 136] = read_depth(tile1 | uint2(1, 1), pixel_coord);

	GroupMemoryBarrierWithGroupSync();

	uint read_index = write_index * 2;
	float d0 = gs_depths[read_index + 0];
	float d1 = gs_depths[read_index + 1];
	float d2 = gs_depths[read_index + 16];
	float d3 = gs_depths[read_index + 17];

    // Do a downsample resolve
    float min_z = min(min(d0, d1), min(d2, d3));
    float max_z = max(max(d0, d1), max(d2, d3));
    bool use_max_z = ((group_thread_id.x ^ group_thread_id.y) & 1) && (abs(d1 + d2 - d0 - d3) > half_res_zminmax_dither_threshold);
    float depth = use_max_z ? max_z : min_z;

    destination_depth_texture[group_id.xy * 8 + pixel_coord] = depth;

    // Compute the depth bounds
    max_z = min_z = depth;
    min_z = min(min_z, __XB_LaneSwizzle(min_z, 0x1F | (0x01 << 10)));
    min_z = min(min_z, __XB_LaneSwizzle(min_z, 0x1F | (0x02 << 10)));
    min_z = min(min_z, __XB_LaneSwizzle(min_z, 0x1F | (0x04 << 10)));
    min_z = min(min_z, __XB_LaneSwizzle(min_z, 0x1F | (0x08 << 10)));
    min_z = min(min_z, __XB_LaneSwizzle(min_z, 0x1F | (0x10 << 10)));
    min_z = min(min_z, __XB_ReadLane(min_z, 32));
    max_z = max(max_z, __XB_LaneSwizzle(max_z, 0x1F | (0x01 << 10)));
    max_z = max(max_z, __XB_LaneSwizzle(max_z, 0x1F | (0x02 << 10)));
    max_z = max(max_z, __XB_LaneSwizzle(max_z, 0x1F | (0x04 << 10)));
    max_z = max(max_z, __XB_LaneSwizzle(max_z, 0x1F | (0x08 << 10)));
    max_z = max(max_z, __XB_LaneSwizzle(max_z, 0x1F | (0x10 << 10)));
    max_z = max(max_z, __XB_ReadLane(max_z, 32));

    // Write HiZ and ZMask to half-res HTile
    // This assumes there is no stencil buffer, which would change the format of the HTile
    if (group_index == 0)
    {
        // Clamp to [0, 1] and convert to fixed precision.  floor(min_z), ceil(max_z)
        uint htile_value = __XB_PackF32ToUNORM16(min_z - 0.5 / 65535.0, max_z + 3.5 / 65535.0);

        // Shift up min_z by 2 bits, then set all four lower bits
        htile_value = __XB_BFI(__XB_BFM(14, 18), htile_value, htile_value << 2) | 0xF;

        uint htile_offset = get_htile_address(group_id.xy, out_htile_info);

        destination_htile.Store(htile_offset, htile_value);
    }
}

#endif