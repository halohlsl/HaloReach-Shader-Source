#ifndef _MATRIX_FX_
#define _MATRIX_FX_

//
//	HLSL matrix routines
//
//
//


float3x3 normalize_rotation_matrix_from_vectors(		// uses vector k directly, and does a projected least squares fit on i, j.  REQUIRES non-zero, distinct input vectors
	in float3 i,
	in float3 j,
	in float3 k)
{
	i= normalize(i);
	j= normalize(j);
	k= normalize(k);

	float3 proj_i=	normalize(i - k * dot(i, k));
	float3 proj_j=  normalize(j - k * dot(j, k));
	
	// midpoint vector
	float3 mid_pij=	(proj_i + proj_j) * 0.5f;
	
	// difference vector  (guaranteed orthogonal to midpoint vector)
	float3 dif_pij=	(proj_j - proj_i) * 0.5f;
	
	//
	// note:		proj_i	==	mid_pij - dif_pij
	//				proj_j	==	mid_pij + dif_pij
	//
	//		What we're gonna do is scale dif_pij so it is the same length as mid_pij.
	//		This makes the new i,j vectors orthogonal (because they're both 45 degrees from the midpoint vector)
	//		and equidistant from their original points.
	//
	
	dif_pij *= length(mid_pij) / length(dif_pij);
	
	float3x3 result;
	result[0]=	normalize(mid_pij - dif_pij);		// modified projected i
	result[1]=	normalize(mid_pij + dif_pij);		// modified projected j
	result[2]=	k;
	
	return result;
}	



#endif // _QUATERNIONS_FX_