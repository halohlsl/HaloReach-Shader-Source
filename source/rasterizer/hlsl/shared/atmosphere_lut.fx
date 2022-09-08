#ifndef __ATMOSPHERE_LUT_FX_H__
#define __ATMOSPHERE_LUT_FX_H__

#include "shared\atmosphere_structs.fx"

// this file defines the atmosphere look-up table mapping


// using CPU code to precompute the parameters of LUT
#define LUT_USING_CPU_PRECOMPUTION
//#undef LUT_USING_CPU_PRECOMPUTION


#ifdef	LUT_USING_CPU_PRECOMPUTION

//	#define PIN_LUT(z)										clamp(z, LUT_Z_FLOOR, LUT_Z_CEILING)
	#define	LUT_DELTA										0.0001

	float LUT_get_z_from_coord(
		in s_atmosphere_precomputed_LUT_constants constants,
		in float x)
	{
		// ###XWAN $TODO $PERF -- remove two ALUs by converting this to a form that can use multiply-add (MAD) instruction:			pow(a*x,b) + zf		===>	const_pow(a,b)	*	pow(x,b)	+	zf;
		float z= pow( constants.LUT_coeff_a*x, constants.LUT_coeff_b) + constants.LUT_Z_FLOOR;
		return z;
	}


	float LUT_get_x_coord(
		in s_atmosphere_precomputed_LUT_constants constants,
		in float3 camera_position,
		in float view_distance,
		in float z)
	{
		float z_geom_diff = abs(z-camera_position.z) + LUT_DELTA;
		float z_table_diff= abs(clamp(z, constants.LUT_Z_FLOOR, constants.LUT_Z_CEILING) - constants.LUT_clamped_view_z) + LUT_DELTA;
		float x=	view_distance * constants.ONE_OVER_MAX_VIEW_DISTANCE *
					z_table_diff/z_geom_diff;
		x= sqrt(x);
		return saturate(x);
	}

	float LUT_get_y_coord(
		in s_atmosphere_precomputed_LUT_constants constants,
		in float z)
	{
		// ###XWAN $TODO $PERF -- use log2/exp2 instead of log/exp here!
		float relative_z= max(z - constants.LUT_Z_FLOOR, LUT_DELTA);
		float y= exp2( log2(relative_z) * constants.LUT_one_over_coeff_b - constants.LUT_log_coeff_a );
		return saturate(y);
	}


#else	// !LUT_USING_CPU_PRECOMPUTION

/*
	#define	MAX_VIEW_DISTANCE					10000.0f
	#define	ONE_OVER_MAX_VIEW_DISTANCE			1.0f/MAX_VIEW_DISTANCE

	#define LUT_GROUND_THICK_RANGE		10.0f
	#define LUT_SKY_THICK_RANGE			20.0f

	#define LUT_Z_FLOOR				\
		min( (_ground_fog_height + _ground_fog_base_height - LUT_GROUND_THICK_RANGE), (_camera_position.z - LUT_GROUND_THICK_RANGE) )


	#define LUT_Z_MIDDLE				\
		max ( (_ground_fog_height+_ground_fog_base_height),  LUT_Z_FLOOR+1.0f)

	#define LUT_Z_CEILING				\
		max ( min ( (_sky_fog_height + _sky_fog_base_height), (_camera_position.z + LUT_SKY_THICK_RANGE) ), LUT_Z_MIDDLE+1.0f )


	#define	PIN_LUT(x)					( min( max(x, LUT_Z_FLOOR), LUT_Z_CEILING ) )

	// it will be evaluated by CPU in the future
	float LUT_evaluate_parameters(
		out float a,
		out float b)
	{
		float M= LUT_Z_CEILING - LUT_Z_FLOOR;
		float N= LUT_Z_MIDDLE - LUT_Z_FLOOR;

		const float log_M= log(M);
		const float log_N= log(N);
		const float log_half= log(0.5f);

		a= exp( (log_half*log_M) / (log_N - log_M) );
		b= (log_N - log_M) / log_half;
	}

	float LUT_get_z_from_coord(in float x)
	{
		float a, b;
		LUT_evaluate_parameters(a, b);

		float z= pow( a*x, b) + LUT_Z_FLOOR;
		return z;
	}

	float LUT_get_x_coord(
		in float view_distance,
		in float scene_z)
	{
		float z_geom_diff = abs(scene_z-_camera_position.z) + 0.0001f;
		float z_table_diff= abs(PIN_LUT(scene_z) - PIN_LUT(_camera_position.z) );
		float x=	view_distance * ONE_OVER_MAX_VIEW_DISTANCE *
					z_table_diff/z_geom_diff;
		x= sqrt(x);
		return saturate(x);
	}

	float LUT_get_y_coord(in float z)
	{
		float a, b;
		LUT_evaluate_parameters(a, b);

		float relative_z= max(z - LUT_Z_FLOOR, 0.01f);
		float y= exp( log(relative_z)/b - log(a) );
		return saturate(y);
	}
*/

#endif	// !LUT_USING_CPU_PRECOMPUTION

#endif // __ATMOSPHERE_LUT_FX_H__
