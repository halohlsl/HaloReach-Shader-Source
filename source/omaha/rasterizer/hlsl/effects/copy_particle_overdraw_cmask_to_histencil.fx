
#include "hlsl_constant_globals.fx"
#include "effects\copy_particle_overdraw_cmask_to_histencil_registers.fx"

#ifdef durango

//@compute_shader
//@entry default
//@entry albedo

// Interpret SR* values from HTile
#define STENCIL_CLEAR 0x0
#define STENCIL_MAY_FAIL 0x1
#define STENCIL_MAY_PASS 0x2
#define STENCIL_MAY_PASS_OR_FAIL 0x3

// Interpret SMem values from HTile
#define SMEM_CLEAR 0x0
#define SMEM_SINGLE_VALUE 0x1
#define SMEM_EXPANDED_AND_CLEAR 0x2
#define SMEM_EXPANDED 0x3

uint untile_htile(in uint2 coord, in uint pitch, in bool is_linear, in bool is_xboxone_x)
{
    uint cachelineDimsWidth = 64;
    uint cachelineDimsHeight = is_xboxone_x ? 64 : 32;

	uint2 cachelineDims;
	uint2 coordSubCacheline;
	uint iCacheline;
	if (is_linear)
	{
		// Linear mode ignores cachelines, so pretend the whole surface is one cacheline
		cachelineDims = uint2( pitch, 1 << 16 );
		coordSubCacheline = coord;
		iCacheline = 0;
	} else
	{
		cachelineDims = uint2(cachelineDimsWidth, cachelineDimsHeight);
		uint2 coordCacheline = coord / cachelineDims;
		coordSubCacheline = coord % cachelineDims;
		uint iHtilePitchInCachelines = pitch / cachelineDims.x;
		iCacheline = coordCacheline.y * iHtilePitchInCachelines + coordCacheline.x;
	}

    const uint2 macroTileDims = is_xboxone_x ? uint2(8, 4) : uint2(4, 4);
    const uint2 coordTileDims = is_xboxone_x ? uint2(8, 8) : uint2(4, 4);
    uint2 coordMacroTile = coordSubCacheline / macroTileDims;
    uint2 coordTile = coordSubCacheline % coordTileDims;
    const uint iCachelinePitchInMacroTiles = cachelineDims.x / macroTileDims.x;
    uint iMacroTileNumBits = firstbithigh( iCachelinePitchInMacroTiles * cachelineDims.y / macroTileDims.y );
    uint iMacroTileNumBitsLow = 4;
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

    return ( iCacheline << ( iBankNumBits + iMacroTileNumBits + iPipeNumBits ) )
        | ( __XB_UBFE( iMacroTileNumBitsHigh, iMacroTileNumBitsLow, iMacroTile ) << ( iBankNumBits + iMacroTileNumBitsLow + iPipeNumBits ) )
        | ( iPipeBits << ( iBankNumBits + iMacroTileNumBitsLow ) )
        | ( __XB_UBFE( iMacroTileNumBitsLow, 0, iMacroTile ) << iBankNumBits )
        | iBankBits;
}

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

void copy_cmask_to_histencil(in uint index, in bool is_xboxone_x)
{
	if (index < max_index)
	{
		uint2 coord = uint2(index % cmask_width, index / cmask_width);
		uint2 histencil_coord = coord  * 2;
		uint cmask_address = untile_cmask(coord, cmask_pitch, is_xboxone_x);
		uint raw_cmask = cmask_buffer[cmask_address / 2];
		uint cmask = (cmask_address & 1) ? ((raw_cmask & 0xf0) >> 4) : raw_cmask & 0xf;

		for (uint x = 0; x < 2; x++)
		{
			for (uint y = 0; y < 2; y++)
			{
				uint htile_address = untile_htile(histencil_coord + uint2(x, y), htile_pitch, false, is_xboxone_x);
				uint htile = htile_buffer[htile_address];
				uint new_histencil = (cmask == 0) ? STENCIL_CLEAR : STENCIL_MAY_PASS;
				uint new_smem = (cmask == 0) ? SMEM_CLEAR : SMEM_SINGLE_VALUE;
				htile = __XB_BFI(htile, ~((3 << 4) | (3 << 8)), (new_histencil << 4) | (new_smem << 8));
				htile_buffer[htile_address] = htile;
			}
		}
	}
}

[numthreads(CS_PARTICLE_OVERDRAW_CMASK_TO_HISTENCIL_THREADS, 1, 1)]
void default_cs(in uint index : SV_DispatchThreadID)
{
	copy_cmask_to_histencil(index, false);
}

[numthreads(CS_PARTICLE_OVERDRAW_CMASK_TO_HISTENCIL_THREADS, 1, 1)]
void albedo_cs(in uint index : SV_DispatchThreadID)
{
	copy_cmask_to_histencil(index, true);
}

#endif
