#ifndef _QUATERNIONS_FX_
#define _QUATERNIONS_FX_

//
//	HLSL quaternion routines
//
//
//		all quaternions are stored {x, y, z, w}
//
//		rotating a point by a quaternion is 8 instructions (as opposed to 3 instructions for a matrix rotation)
//

#if defined(pc) || (DX_VERSION == 11)
#define QUATERNIONS_USE_UNOPTIMIZED_HLSL
#endif


float4 quaternion_multiply(float4 q0, float4 q1)		// multiplies q0 by q1   (quaternions are x,y,z,w)
{
	float4 result;

#ifdef QUATERNIONS_USE_UNOPTIMIZED_HLSL
	result = float4(cross(q0.xyz, q1.xyz),							// crs result.xyz_, q0.xyz ,  q1.xyz
			-dot(q0.xyz, q1.xyz));									// dp3 result.___w, q0.xyz , -q1.xyz
	result.xyz  += q0.w * q1.xyz;									// mad result.xyz_, q0.www ,  q1.xyz ,  result.xyz
	result.xyzw += q1.w * q0.xyzw;									// mad result.xyzw, q1.wwww,  q0.xyzw,  result.xyzw
#else

	// I don't trust the compiler...
	asm {
		dp3 result.w,		q0.xyz,			-q1.xyz
		mul result.xyz,		q0.zxy,			 q1.yzx						// cross part 1
		mad result.xyz,		q0.yzx,			 q1.zxy,	-result.xyz		// cross part 2
		mad result.xyz,		q0.w,			 q1.xyz,	 result.xyz
		mad result,			q1.w,			 q0,		 result
	};
#endif

	return result;
}


float4 quaternion_multiply_conjugate(float4 q0, float4 q1)	// multiplies q0 by the conjugate of q1
{
	float4 result;

#ifdef QUATERNIONS_USE_UNOPTIMIZED_HLSL
	result= quaternion_multiply(q0, float4(-q1.xyz, q1.w));
#else

	// same as quaternion multiply, but with negated xyz components
	asm {
		dp3 result.w,		q0.xyz,			 q1.xyz
		mul result.xyz,		q0.zxy,			-q1.yzx						// cross part 1
		mad result.xyz,		q0.yzx,			-q1.zxy,	-result.xyz		// cross part 2
		mad result.xyz,		q0.w,			-q1.xyz,	 result.xyz
		mad result,			q1.w,			 q0,		 result
	};
#endif

	return result;
}


float3 quaternion_transform_point(float4 q, float3 pt)		// transform point pt by q
{
	float4 result;

#ifdef QUATERNIONS_USE_UNOPTIMIZED_HLSL
	result= quaternion_multiply_conjugate(float4(pt, 0), q);			// pt' = q pt q'
	result= quaternion_multiply(q, result);
#else

	// compiler really fucks up this one if I don't give it the assembly...
	float4 temp;
	asm {
		// compute pt * q'	assuming p.w == 0
		dp3 temp.w,			pt.xyz,		 q.xyz
		mul temp.xyz,		pt.zxy,		-q.yzx						// cross part 1
		mad temp.xyz,		pt.yzx,		-q.zxy,		-temp.xyz		// cross part 2
//		mad temp.xyz,		pt.w,		-q.xyz,		 temp.xyz		// nop when pt.w == 0
		mad temp.xyz,		q.w,		 pt.xyz,	 temp.xyz		// pt.w is zero

		// compute q * temp	(don't need to compute w)
//		dp3 result.w,		q.xyz,		-temp.xyz					// don't need w component
		mul result.xyz,		q.zxy,		 temp.yzx					// cross part 1
		mad result.xyz,		q.yzx,		 temp.zxy,	-result.xyz		// cross part 2
		mad result.xyz,		q.w,		 temp.xyz,	 result.xyz
		mad result.xyz,		temp.w,		 q.xyz,		 result.xyz
	};
#endif

	return result.xyz;
}


float4 quaternion_from_unit_vectors(
	in float3 a,
	in float3 b)
{
	float4 result;

	// NOTE:  this code doesn't handle input vectors that are 180 degrees apart

	float normalization_factor= sqrt(2 + 2 * dot(a, b));		//	[0, 2]
	result.xyz= cross(a, b) / normalization_factor;
	result.w= normalization_factor * 0.5f;						//	(1 + dot(a, b)) / normalization_factor;

//	float scale= sqrt(max(2 + 2*dot(a, b), 0.0f));
//	if (scale>=k_valid_real_epsilon)
//	{
//		result.xyz= cross(a, b) / scale;
//		result.w= scale * 0.5f;
//	}
//	else
//	{	// 180 degrees
//		perpendicular3d(a, &q->v);
//		q->w= 0;
//	}

	return result;
}


#endif // _QUATERNIONS_FX_