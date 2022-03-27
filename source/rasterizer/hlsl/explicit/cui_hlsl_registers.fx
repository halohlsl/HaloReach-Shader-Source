#ifndef __CUI_HLSL_REGISTERS_FX__
#define __CUI_HLSL_REGISTERS_FX__

//NOTE: if you modify any of this, than you need to modify cui_hlsl_registers.h 

#undef VERTEX_CONSTANT
#undef PIXEL_CONSTANT
#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index)
	#define PIXEL_CONSTANT(type, name, register_index)   type name
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index)
#endif

VERTEX_CONSTANT(float4x4, k_cui_vertex_shader_constant_projection_matrix, c30);
VERTEX_CONSTANT(float4x3, k_cui_vertex_shader_constant_model_view_matrix, c34);
VERTEX_CONSTANT(float4, k_cui_vertex_shader_constant0, c37);

PIXEL_CONSTANT(float4, k_cui_pixel_shader_color0, c30);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color1, c31);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color2, c32);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color3, c33);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color4, c34);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_color5, c35);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar0, c36);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar1, c37);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar2, c38);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar3, c39);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar4, c40);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar5, c41);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar6, c42);
PIXEL_CONSTANT(float, k_cui_pixel_shader_scalar7, c43);

PIXEL_CONSTANT(float4, k_cui_pixel_shader_bounds, c44);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_pixel_size, c45);
PIXEL_CONSTANT(float4, k_cui_pixel_shader_tint, c46);

// <scale, offset, bool need_to_premultiply>
// premultiplied (render target): <1, 0, 1>
// non-premultiplied (source bitmap): <-1, 1, 0>
PIXEL_CONSTANT(float4, k_cui_sampler0_transform, c47);
PIXEL_CONSTANT(float4, k_cui_sampler1_transform, c48);

sampler2D source_sampler0 : register(s0);
sampler2D source_sampler1 : register(s1);

#endif // __CUI_HLSL_REGISTERS_FX__
