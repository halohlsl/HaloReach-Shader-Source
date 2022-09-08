#if DX_VERSION == 9

// -----------------------------------------------------------------------
// shader constants define, please refer to sky_atm\planar_fog.cpp
// -----------------------------------------------------------------------
PIXEL_CONSTANT(float4x4, k_ps_view_xform_inverse, 213)
PIXEL_CONSTANT(float4, k_ps_planar_fog_settings_0, 217)
PIXEL_CONSTANT(float4, k_ps_planar_fog_settings_1, 218)
PIXEL_CONSTANT(float4, k_ps_planar_fog_settings_2, 219)

// palette
PIXEL_CONSTANT(float4, k_ps_planar_fog_palette_settings, 221)

// patchy
PIXEL_CONSTANT(float4, k_ps_patchy_effect_color, 124)
PIXEL_CONSTANT(float4, k_ps_inverse_z_transform, 125)
PIXEL_CONSTANT(float4, k_ps_texcoord_basis, 126)
PIXEL_CONSTANT(float4, k_ps_attenuation_data, 127)
PIXEL_CONSTANT(float4, k_ps_eye_position, 128)
PIXEL_CONSTANT(float4, k_ps_window_pixel_bounds, 129)
PIXEL_CONSTANT(float4, k_ps_sheet_fade_factors0, 130)
PIXEL_CONSTANT(float4, k_ps_sheet_fade_factors1, 131)
PIXEL_CONSTANT(float4, k_ps_sheet_depths0, 132)
PIXEL_CONSTANT(float4, k_ps_sheet_depths1, 133)

// texture coordinate transforms for each sheet
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform0, 134)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform1, 135)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform2, 136)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform3, 137)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform4, 138)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform5, 139)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform6, 140)
PIXEL_CONSTANT(float4, k_ps_tex_coord_transform7, 141)

SAMPLER_CONSTANT(k_ps_planar_fog_sampler_depth_buffer, 1)
SAMPLER_CONSTANT(k_ps_planar_fog_sampler_patchy_effect, 3)
SAMPLER_CONSTANT(k_ps_planar_fog_sampler_palette, 4)

BOOL_CONSTANT(k_bool_enable_patchy_effect, 10)
BOOL_CONSTANT(k_bool_enable_color_palette, 11)
BOOL_CONSTANT(k_bool_enable_alpha_palette, 12)

#elif DX_VERSION == 11

CBUFFER_BEGIN(PlanarFogPS)
	CBUFFER_CONST(PlanarFogPS,		float4x4, 	k_ps_view_xform_inverse, 			k_ps_view_xform_inverse)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_planar_fog_settings_0, 		k_ps_planar_fog_settings_0)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_planar_fog_settings_1, 		k_ps_planar_fog_settings_1)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_planar_fog_settings_2, 		k_ps_planar_fog_settings_2)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_planar_fog_palette_settings, 	k_ps_planar_fog_palette_settings)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_patchy_effect_color, 			k_ps_patchy_effect_color)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_inverse_z_transform, 			k_ps_inverse_z_transform)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_texcoord_basis, 				k_ps_texcoord_basis)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_attenuation_data, 				k_ps_attenuation_data)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_eye_position, 					k_ps_eye_position)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_window_pixel_bounds, 			k_ps_window_pixel_bounds)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_sheet_fade_factors0, 			k_ps_sheet_fade_factors0)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_sheet_fade_factors1, 			k_ps_sheet_fade_factors1)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_sheet_depths0, 				k_ps_sheet_depths0)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_sheet_depths1, 				k_ps_sheet_depths1)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform0, 			k_ps_tex_coord_transform0)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform1, 			k_ps_tex_coord_transform1)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform2, 			k_ps_tex_coord_transform2)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform3, 			k_ps_tex_coord_transform3)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform4, 			k_ps_tex_coord_transform4)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform5, 			k_ps_tex_coord_transform5)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform6, 			k_ps_tex_coord_transform6)
	CBUFFER_CONST(PlanarFogPS,		float4, 	k_ps_tex_coord_transform7, 			k_ps_tex_coord_transform7)

	CBUFFER_CONST(PlanarFogPS,		bool,		k_bool_enable_patchy_effect, 		k_bool_enable_patchy_effect)
	CBUFFER_CONST(PlanarFogPS,		bool,		k_bool_enable_color_palette, 		k_bool_enable_color_palette)
	CBUFFER_CONST(PlanarFogPS,		bool,		k_bool_enable_alpha_palette, 		k_bool_enable_alpha_palette)
CBUFFER_END


PIXEL_TEXTURE_AND_SAMPLER(_2D, 	k_ps_planar_fog_sampler_depth_buffer, 	k_ps_planar_fog_sampler_depth_buffer,	1)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	k_ps_planar_fog_sampler_patchy_effect, 	k_ps_planar_fog_sampler_patchy_effect, 	3)
PIXEL_TEXTURE_AND_SAMPLER(_2D,	k_ps_planar_fog_sampler_palette, 		k_ps_planar_fog_sampler_palette,		4)

#endif
