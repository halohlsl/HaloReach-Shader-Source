#ifndef __ATMOSPHERE_STRUCTS_FX__
#define __ATMOSPHERE_STRUCTS_FX__

struct s_atmosphere_constants
{
	float4 atm_data0;
	float4 atm_data1;
	float4 atm_data2;
	float4 atm_data3;

#ifndef DEFINE_CPP_CONSTANTS
	#define _sky_fog_color					atm_data0.xyz
	#define _sky_fog_thickness				atm_data0.w
	#define _sky_fog_height					atm_data1.x
	#define _sky_fog_base_height			atm_data1.y
	#define _sky_fog_max_distance			atm_data1.z
	#define _fog_distance_bias				atm_data1.w

	#define _ground_fog_color				atm_data2.xyz
	#define _ground_fog_thickness			atm_data2.w
	#define _ground_fog_height				atm_data3.x
	#define _ground_fog_base_height			atm_data3.y
	#define _ground_fog_max_distance		atm_data3.z
	#define _fog_extinction_threshold		atm_data3.w
#endif
};


struct s_fog_light_constants
{
	float4 fog_data0;
	float4 fog_data1;
	float4 fog_data2;

#ifndef DEFINE_CPP_CONSTANTS
	// ---------------  translate constants for fog lights
	#define _fog_light_1_direction			fog_data0.xyz
	#define _fog_light_1_radius_scale		fog_data0.w
	#define _fog_light_1_color				fog_data1.xyz
	#define _fog_light_1_radius_offset		fog_data1.w

	#define _fog_light_1_angular_falloff	fog_data2.x
	#define _fog_light_1_distance_falloff	fog_data2.y
	#define _fog_light_1_nearby_cutoff		fog_data2.z
#endif
};

struct s_atmosphere_precomputed_LUT_constants
{
	float4 lut_data[4];

#ifndef DEFINE_CPP_CONSTANTS
	#define MAX_VIEW_DISTANCE							lut_data[0].x
	#define ONE_OVER_MAX_VIEW_DISTANCE					lut_data[0].y
	#define	LUT_Z_FLOOR									lut_data[0].z
	#define	LUT_Z_CEILING								lut_data[0].w

	#define LUT_coeff_a									lut_data[1].x
	#define LUT_coeff_b									lut_data[1].y
	#define	LUT_clamped_view_z							lut_data[1].z
	#define	LUT_Z_MIDDLE								lut_data[1].w

	#define	LUT_one_over_coeff_b						lut_data[2].x
	#define	LUT_log_coeff_a								lut_data[2].y
	#define	LUT_log2_coeff_a							lut_data[2].z

	#define	LUT_y_map_coeffs							lut_data[3]
#endif
};

#endif
