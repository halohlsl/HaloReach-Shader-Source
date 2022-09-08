#ifndef __PROCEDURAL_GEOMETRY_FX__
#define __PROCEDURAL_GEOMETRY_FX__



// if QUAD_INDEX_MOD4 is defined, the operations below will apply the (mod 4) operation to the index, so you can generate multiple quads from the same index stream
#ifdef QUAD_INDEX_MOD4
#define QUAD_MOD4(index) (frac((index)/4)*4)
#else
#define QUAD_MOD4(index) (index)
#endif



float2 generate_quad_point_2d(		// produces the given corner of the unit-size axis-aligned quad (in the range [0,1])
	float index_int)
{
#ifdef pc
	float2 verts[4]=
	{
		float2( 0.0f, 0.0f ),	// 0
		float2( 1.0f, 0.0f ),	// 1
#if DX_VERSION == 11
		float2( 0.0f, 1.0f ),	// 2
		float2( 1.0f, 1.0f ),	// 3
#else
		float2( 1.0f, 1.0f ),	// 2
		float2( 0.0f, 1.0f ),	// 3
#endif
	};
	return verts[QUAD_MOD4(index_int)];
#else // xenon
	// this compiles to 3 ALUs w/no waterfalling, (versus ~9 ALUs for the above pc version)
	return		(frac(index_int * 0.25f + float2(0.25f, 0.0f)) >= 0.5f);
#endif // xenon
}


float2 generate_quad_point_centered_2d(		// produces the given corner of the unit-size axis-aligned quad (in the range [-0.5,0.5])
	float index_int)
{
	return generate_quad_point_2d(index_int) - 0.5f;		// I can't think of any faster way to do this...
}


float2 generate_scaled_quad_point_2d(		// produces the given corner of the scaled axis-aligned quad (in the range [origin,origin+size])
	float index_int,
	float2 origin,
	float2 size)
{
#ifdef QUAD_INDEX_MOD4
	return	origin + size * generate_quad_point_2d(index_int);
#else // !MOD4
	return	origin + ((index_int * 0.25f - float2(0.25f, 0.5f)) >= 0.0f ? 0.0f : size.xy);
#endif // !MOD4
}


float2 generate_rotated_quad_point_2d(
	float index_int,
	float2 origin,
	float2 dx)
{
	float2 coord=	generate_quad_point_2d(index_int) - 0.5f;

	return	origin + coord.x * dx + coord.y * float2(-dx.y, dx.x);
}



#endif // __PROCEDURAL_GEOMETRY_FX__