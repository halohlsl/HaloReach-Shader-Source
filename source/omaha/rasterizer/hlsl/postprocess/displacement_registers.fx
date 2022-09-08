/*
DISPLACEMENT_REGISTERS.FX
Copyright (c) Microsoft Corporation, 2007. all rights reserved.
3/21/2007 4:57:42 PM (davcook)

*/

// ###ctchou $TODO alot of these are unused - remove them!

#if DX_VERSION == 9

// screen_constants.xy == 1/pixel resolution
// screen_constants.zw == screenshot_scale
PIXEL_CONSTANT(float4, screen_constants, 203)

// resolution_constants.xy == pixel resolution (width, height)
// resolution_constants.zw == 1.0 / pixel resolution
PIXEL_CONSTANT(float4, resolution_constants, 207)
VERTEX_CONSTANT(float4, vs_resolution_constants, 250)

// half_pixel_constants.xy == 0.5f / pixel_resolution
PIXEL_CONSTANT(float4, half_pixel_constants, 208)

// distort_constants.xy == (screenshot scale) * 2 * max_displacement * (0.5f if multisampled) * resolution.xy		<----------------- convert to pixels
// distort_constants.zw == -distortion_offset * distort_constants.xy
PIXEL_CONSTANT(float4, distort_constants, 205)

PIXEL_CONSTANT(float4, window_bounds, 204)

PIXEL_CONSTANT(float4x4, current_view_projection, 160)
PIXEL_CONSTANT(float4x4, previous_view_projection, 164)
PIXEL_CONSTANT(float4x4, screen_to_world, 168)
PIXEL_CONSTANT(float4x4, combined1, 180)
PIXEL_CONSTANT(float4x4, combined2, 184)
PIXEL_CONSTANT(float4x4, combined3, 188)
PIXEL_CONSTANT(float4x4, combined4, 192)

#ifndef pc
INT_CONSTANT(num_taps, 2)
INT_CONSTANT(num_taps2, 3)
INT_CONSTANT(num_taps3, 4)
#endif // pc

// .x= num taps
// .y= motion blur time scale adjustment, for really slow or really long frames [unused due to optimization]
// .z= expected DT between frames [unused due to optimization]
// .w= blur center falloff
PIXEL_CONSTANT(float4, misc_values, 172)
PIXEL_CONSTANT(float4, pixel_misc_values, 159)

// .x= max blur X
// .y= max blur Y
// .z= blur scale X * misc_values.y (optimization; premultiplied)		(total_scale)
// .w= blur scale Y * misc_values.y (optimization; premultiplied)
PIXEL_CONSTANT(float4, blur_max_and_scale, 173)

// .x = total scale
// .y = max blur / total scale
// .z = inverse_num_taps * total scale
// .w = inverse_num_taps * 2 * total scale
PIXEL_CONSTANT(float4, blur_constants, 206)

// .x = total scale
// .y = max blur / total scale
// .z = inverse_num_taps * total scale
// .w = inverse_num_taps * 2 * total scale
PIXEL_CONSTANT(float4, pixel_blur_constants, 158)

// center.xy == clip coordinates
// center.zw == pixel coordinates
PIXEL_CONSTANT(float4, crosshair_center, 174)

// .xy == misc.w
// .zw == (-center_pixel) * misc.w
PIXEL_CONSTANT(float4, crosshair_constants, 209)
VERTEX_CONSTANT(float4, vs_crosshair_constants, 251)

BOOL_CONSTANT(do_distortion, 2)

#elif DX_VERSION == 11

CBUFFER_BEGIN(DisplacementVS)
	CBUFFER_CONST(DisplacementVS,				float4,		vs_resolution_constants,		k_vs_displacement_resolution_constants)
CBUFFER_END

CBUFFER_BEGIN(DisplacementPS)
	CBUFFER_CONST(DisplacementPS,				float4,		screen_constants,				k_ps_displacement_screen_constants)
	CBUFFER_CONST(DisplacementPS,				float4,		resolution_constants,			k_ps_displacement_resolution_constants)
	CBUFFER_CONST(DisplacementPS,				float4,		distort_constants,				k_ps_displacement_distort_constants)
	CBUFFER_CONST(DisplacementPS,				float4,		window_bounds, 					k_ps_displacement_window_bounds)
	CBUFFER_CONST(DisplacementPS,				float4x4, 	combined3, 						k_ps_displacement_combined3)
CBUFFER_END

CBUFFER_BEGIN(DisplacementMotionBlurVS)
	CBUFFER_CONST(DisplacementMotionBlurVS,		float4, 	vs_crosshair_constants,			k_vs_displacement_motion_blur_crosshair_constants)
CBUFFER_END

CBUFFER_BEGIN(DisplacementMotionBlurPS)
	CBUFFER_CONST(DisplacementMotionBlurPS,		int4,		num_taps, 						k_ps_displacement_motion_blur_num_taps)
	CBUFFER_CONST(DisplacementMotionBlurPS,		float4, 	blur_constants,					k_ps_displacement_motion_blur_blur_constants)
	CBUFFER_CONST(DisplacementMotionBlurPS,		float4, 	pixel_blur_constants,			k_ps_displacement_motion_blur_pixel_blur_constants)
	CBUFFER_CONST(DisplacementMotionBlurPS,		float4, 	crosshair_constants,			k_ps_displacement_motion_blur_crosshair_constants)
	CBUFFER_CONST(DisplacementMotionBlurPS,		bool, 		do_distortion,					k_ps_displacement_motion_blur_do_distortion)
CBUFFER_END

#endif
