#if DX_VERSION == 9

// vertex shader/constant decl for all chud shaders

// global constants
VERTEX_CONSTANT(float4, chud_screen_size, c19); // final_size_x, final_size_y, virtual_size_x, virtual_size_y
VERTEX_CONSTANT(float4, chud_basis_01, c20);
VERTEX_CONSTANT(float4, chud_basis_23, c21);
VERTEX_CONSTANT(float4, chud_basis_45, c22);
VERTEX_CONSTANT(float4, chud_basis_67, c23);
VERTEX_CONSTANT(float4, chud_basis_8, c24);
VERTEX_CONSTANT(float4, chud_screen_scale_and_offset, c25); // screen_offset_x, screen_half_scale_x, screen_offset_y, screen_half_scale_y
VERTEX_CONSTANT(float4, chud_project_scale_and_offset, c26); // x_scale, y_scale, offset_z, z_value_scale
VERTEX_CONSTANT(float4, chud_screenshot_info, c27); // <scale_x, scale_y, offset_x, offset_y>

// per widget constants
VERTEX_CONSTANT(float4, chud_widget_offset, c28);
VERTEX_CONSTANT(float4, chud_widget_transform1, c29);
VERTEX_CONSTANT(float4, chud_widget_transform2, c30);
VERTEX_CONSTANT(float4, chud_widget_transform3, c31);
VERTEX_CONSTANT(float4, chud_texture_transform, c32); // <scale_x, scale_y, offset_x, offset_y>

VERTEX_CONSTANT(float4, chud_widget_mirror, c33); // <mirror_x, mirror_y, 0, 0>

// global constants
PIXEL_CONSTANT(float4, chud_savedfilm_data1, c24); // <record_min, buffered_theta, bar_theta, 0.0>
PIXEL_CONSTANT(float4, chud_savedfilm_chap1, c25); // <chap0..3>
PIXEL_CONSTANT(float4, chud_savedfilm_chap2, c26); // <chap4..7>
PIXEL_CONSTANT(float4, chud_savedfilm_chap3, c27); // <chap8,9,-1,-1>

// per widget constants
PIXEL_CONSTANT(float4, chud_color_output_A, c28);
PIXEL_CONSTANT(float4, chud_color_output_B, c29);
PIXEL_CONSTANT(float4, chud_color_output_C, c30);
PIXEL_CONSTANT(float4, chud_color_output_D, c31);
PIXEL_CONSTANT(float4, chud_color_output_E, c32);
PIXEL_CONSTANT(float4, chud_color_output_F, c33);
PIXEL_CONSTANT(float4, chud_scalar_output_ABCD, c34);// [a, b, c, d]
PIXEL_CONSTANT(float4, chud_scalar_output_EF, c35);// [e, f, 0, global_hud_alpha]
PIXEL_CONSTANT(float4, chud_texture_bounds, c36); // <x0, x1, y0, y1>
PIXEL_CONSTANT(float4, chud_widget_transform1_ps, c37);
PIXEL_CONSTANT(float4, chud_widget_transform2_ps, c38);
PIXEL_CONSTANT(float4, chud_widget_transform3_ps, c39);

PIXEL_CONSTANT(float4, chud_widget_mirror_ps, c40);

// damage flash constants
PIXEL_CONSTANT(float4, chud_screen_flash0_color, c41); // rgb, alpha
PIXEL_CONSTANT(float4, chud_screen_flash0_data, c42); // virtual_x, virtual_y, center size, offscreen size
PIXEL_CONSTANT(float4, chud_screen_flash0_scale, c43); // center alpha, offscreen alpha, inner alpha, outer alpha
PIXEL_CONSTANT(float4, chud_screen_flash1_color, c44); // rgb, inner alpha
PIXEL_CONSTANT(float4, chud_screen_flash1_data, c45); // virtual_x, virtual_y, center size, offscreen size
PIXEL_CONSTANT(float4, chud_screen_flash1_scale, c46); // center alpha, offscreen alpha, inner alpha, outer alpha
PIXEL_CONSTANT(float4, chud_screen_flash2_color, c47); // rgb, inner alpha
PIXEL_CONSTANT(float4, chud_screen_flash2_data, c48); // virtual_x, virtual_y, center size, offscreen size
PIXEL_CONSTANT(float4, chud_screen_flash2_scale, c49); // center alpha, offscreen alpha, inner alpha, outer alpha
PIXEL_CONSTANT(float4, chud_screen_flash3_color, c50); // rgb, inner alpha
PIXEL_CONSTANT(float4, chud_screen_flash3_data, c51); // virtual_x, virtual_y, center size, offscreen size
PIXEL_CONSTANT(float4, chud_screen_flash3_scale, c52); // center alpha, offscreen alpha, inner alpha, outer alpha
PIXEL_CONSTANT(float4, chud_screen_flash_center, c53); // crosshair_x, crosshair_y, unused, unused
PIXEL_CONSTANT(float4, chud_screen_flash_scale, c54); // scale, falloff, inner_alpha, outer_alpha

PIXEL_CONSTANT(bool, chud_comp_colorize_enabled, b8);

#elif DX_VERSION == 11

CBUFFER_BEGIN(CHUDVS)
	CBUFFER_CONST(CHUDVS,				float4,		chud_screen_size,					k_vs_chud_screen_size)
	CBUFFER_CONST(CHUDVS,				float4,		chud_basis_01,						k_vs_chud_basis_01)
	CBUFFER_CONST(CHUDVS,				float4,		chud_basis_23,						k_vs_chud_basis_23)
	CBUFFER_CONST(CHUDVS,				float4,		chud_basis_45,						k_vs_chud_basis_45)
	CBUFFER_CONST(CHUDVS,				float4,		chud_basis_67,						k_vs_chud_basis_67)
	CBUFFER_CONST(CHUDVS,				float4,		chud_basis_8,						k_vs_chud_basis_8)
	CBUFFER_CONST(CHUDVS,				float4,		chud_screen_scale_and_offset,		k_vs_chud_screen_scale_and_offset)
	CBUFFER_CONST(CHUDVS,				float4,		chud_project_scale_and_offset,		k_vs_chud_project_scale_and_offset)
	CBUFFER_CONST(CHUDVS,				float4,		chud_screenshot_info,				k_vs_chud_screenshot_info)
CBUFFER_END

CBUFFER_BEGIN(CHUDWidgetVS)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_widget_offset,					k_vs_chud_widget_offset)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_widget_transform1,				k_vs_chud_widget_transform1)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_widget_transform2,				k_vs_chud_widget_transform2)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_widget_transform3,				k_vs_chud_widget_transform3)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_texture_transform,				k_vs_chud_texture_transform)
	CBUFFER_CONST(CHUDWidgetVS,			float4, 	chud_widget_mirror,					k_vs_chud_widget_mirror)
CBUFFER_END

CBUFFER_BEGIN(CHUDPS)
	CBUFFER_CONST(CHUDPS,				float4,		chud_savedfilm_data1,				k_ps_chud_savedfilm_data1)
	CBUFFER_CONST(CHUDPS,				float4,		chud_savedfilm_chap1,				k_ps_chud_savedfilm_chap1)
	CBUFFER_CONST(CHUDPS,				float4,		chud_savedfilm_chap2,				k_ps_chud_savedfilm_chap2)
	CBUFFER_CONST(CHUDPS,				float4,		chud_savedfilm_chap3,				k_ps_chud_savedfilm_chap3)
CBUFFER_END

CBUFFER_BEGIN(CHUDWidgetPS)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_A,				k_ps_chud_color_output_A)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_B,				k_ps_chud_color_output_B)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_C,				k_ps_chud_color_output_C)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_D,				k_ps_chud_color_output_D)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_E,				k_ps_chud_color_output_E)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_color_output_F,				k_ps_chud_color_output_F)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_scalar_output_ABCD,			k_ps_chud_scalar_output_ABCD)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_scalar_output_EF,				k_ps_chud_scalar_output_EF)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_texture_bounds,				k_ps_chud_texture_bounds)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_widget_transform1_ps,			k_ps_chud_widget_transform1)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_widget_transform2_ps,			k_ps_chud_widget_transform2)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_widget_transform3_ps,			k_ps_chud_widget_transform3)
	CBUFFER_CONST(CHUDWidgetPS,			float4, 	chud_widget_mirror_ps,				k_ps_chud_widget_mirror)
CBUFFER_END

CBUFFER_BEGIN(CHUDScreenFlashPS)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash0_color,			k_ps_chud_screen_flash0_color)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash0_data,			k_ps_chud_screen_flash0_data)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash0_scale,			k_ps_chud_screen_flash0_scale)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash1_color,			k_ps_chud_screen_flash1_color)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash1_data,			k_ps_chud_screen_flash1_data)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash1_scale,			k_ps_chud_screen_flash1_scale)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash2_color,			k_ps_chud_screen_flash2_color)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash2_data,			k_ps_chud_screen_flash2_data)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash2_scale,			k_ps_chud_screen_flash2_scale)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash3_color,			k_ps_chud_screen_flash3_color)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash3_data,			k_ps_chud_screen_flash3_data)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash3_scale,			k_ps_chud_screen_flash3_scale)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash_center,			k_ps_chud_screen_flash_center)
	CBUFFER_CONST(CHUDScreenFlashPS,	float4, 	chud_screen_flash_scale,			k_ps_chud_screen_flash_scale)
	CBUFFER_CONST(CHUDScreenFlashPS,	bool, 		chud_comp_colorize_enabled,			k_ps_chud_comp_colorize_enabled)
CBUFFER_END

#endif
