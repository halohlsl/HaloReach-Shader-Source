#ifdef durango

uint untile_cmask(in uint2 coord, in uint pitch, in bool is_xboxone_x)
{
	const uint2 macroTileDims = is_xboxone_x ? uint2(8, 4) : uint2(4, 4);
	const uint2 coordTileDims = is_xboxone_x ? uint2(8, 8) : uint2(4, 4);
	uint2 coordMacroTile = coord / macroTileDims;
	uint2 coordTile = coord % coordTileDims;
	const uint iCachelinePitchInMacroTiles = pitch / macroTileDims.x;
	uint iMacroTileNumBits = firstbithigh( iCachelinePitchInMacroTiles * ( 1 << 16 ) / macroTileDims.y );
	uint iMacroTileNumBitsLow = 7;
	uint iMacroTileNumBitsHigh = iMacroTileNumBits - iMacroTileNumBitsLow;
	uint iMacroTile = coordMacroTile.y * iCachelinePitchInMacroTiles + coordMacroTile.x;

	uint2 iTileBits[3];
	uint iPipeBits;
	uint iPipeNumBits;
	if (is_xboxone_x)
	{
		iTileBits[0] = uint2(__XB_UBFE(1, 0, coordTile.x), __XB_UBFE(1, 0, coordTile.y));
		iTileBits[1] = uint2(__XB_UBFE(1, 1, coordTile.x), __XB_UBFE(1, 1, coordTile.y));
		iTileBits[2] = uint2(__XB_UBFE(1, 2, coordTile.x), __XB_UBFE(1, 2, coordTile.y));

		iPipeBits =
			((iTileBits[0].x ^ iTileBits[0].y ^ iTileBits[1].x) << 0)
			| ((iTileBits[1].x ^ iTileBits[1].y) << 1)
			| ((iTileBits[2].x ^ iTileBits[2].y) << 2);
		iPipeNumBits = 3;
	} else
	{
		iTileBits[0] = uint2( __XB_UBFE( 1, 0, coordTile.x ), __XB_UBFE( 1, 0, coordTile.y ) );
		iTileBits[1] = uint2( __XB_UBFE( 1, 1, coordTile.x ), __XB_UBFE( 1, 1, coordTile.y ) );

		iPipeBits =
			( ( iTileBits[ 0 ].x ^ iTileBits[ 0 ].y ^ iTileBits[ 1 ].x ) << 0 )
			| ( ( iTileBits[ 1 ].x ^ iTileBits[ 1 ].y ) << 1 );
		iPipeNumBits = 2;
	}

	uint iBankBits =
		( ( iTileBits[ 1 ].x ^ iTileBits[ 0 ].y ) << 0 )
		| ( ( iTileBits[ 1 ].x ) << 1 );
	uint iBankNumBits = 2;

	return ( __XB_UBFE( iMacroTileNumBitsHigh, iMacroTileNumBitsLow, iMacroTile ) << ( iBankNumBits + iMacroTileNumBitsLow + iPipeNumBits ) )
		| ( iPipeBits << ( iBankNumBits + iMacroTileNumBitsLow ) )
		| ( __XB_UBFE( iMacroTileNumBitsLow, 0, iMacroTile ) << iBankNumBits )
		| iBankBits;
}

uint read_cmask(in Buffer<uint> cmask_buffer, in uint2 coord, in uint pitch, in bool is_xboxone_x)
{
	uint cmask_address = untile_cmask(coord, pitch, is_xboxone_x);
	uint raw_cmask = cmask_buffer[cmask_address / 2];
	return (cmask_address & 1) ? ((raw_cmask & 0xf0) >> 4) : (raw_cmask & 0xf);
}

float4 sample_compressed_texture(in Texture2D<float4> t, in Buffer<uint> cmask_buffer, uint cmask_pitch, in uint2 coord, in bool is_xboxone_x)
{
	uint2 cmask_coord = coord >> 3;
	uint cmask = read_cmask(cmask_buffer, cmask_coord, cmask_pitch, is_xboxone_x);
	uint tile_bit = ((coord.x >> 2) & 1) | ((coord.y >> 1) & 2);
	return (cmask & (1 << tile_bit)) ? t.Load(uint3(coord, 0)) : float4(0, 0, 0, 1);
}

float4 bilinear_sample_compressed_texture(in Texture2D<float4> t, in Buffer<uint> cmask_buffer, uint cmask_pitch, in float2 pixel_coord, in bool is_xboxone_x)
{
	uint2 ipixel_coord = uint2(pixel_coord);
	float4 t00 = sample_compressed_texture(t, cmask_buffer, cmask_pitch, ipixel_coord, is_xboxone_x);
	float4 t10 = sample_compressed_texture(t, cmask_buffer, cmask_pitch, ipixel_coord + uint2(1, 0), is_xboxone_x);
	float4 t01 = sample_compressed_texture(t, cmask_buffer, cmask_pitch, ipixel_coord + uint2(0, 1), is_xboxone_x);
	float4 t11 = sample_compressed_texture(t, cmask_buffer, cmask_pitch, ipixel_coord + uint2(1, 1), is_xboxone_x);
	float2 fpixel_coord = frac(pixel_coord);
	float4 t0 = (t00 * (1 - fpixel_coord.x)) + (t10 * fpixel_coord.x);
	float4 t1 = (t01 * (1 - fpixel_coord.x)) + (t11 * fpixel_coord.x);
	return (t0 * (1 - fpixel_coord.y)) + (t1 * fpixel_coord.y);
}

#endif
