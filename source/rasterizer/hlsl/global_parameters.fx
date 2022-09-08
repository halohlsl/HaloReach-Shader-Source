#ifndef _PARAMETERS_FX_
#define _PARAMETERS_FX_

#if DX_VERSION == 9

// Exposed parameters

#define PARAM(_type, _name) extern _type _name
#define PARAM_STRUCT(_type, _name) extern _type _name
#define PARAM_ARRAY(_type, _name, _dim) extern _type _name _dim
#define PARAM_SAMPLER_2D_TYPED(_name, _type) extern sampler _name
#define PARAM_SAMPLER_2D_FIXED_TYPED(_name, _slot, _type) extern sampler _name : register(s##_slot)
#define PARAM_SAMPLER_3D_TYPED(_name, _type) extern sampler _name
#define PARAM_SAMPLER_3D_FIXED_TYPED(_name, _slot, _type) extern sampler _name : register(s##_slot)
#define PARAM_SAMPLER_CUBE_TYPED(_name, _type) extern sampler _name
#define PARAM_SAMPLER_CUBE_FIXED_TYPED(_name, _slot, _type) extern sampler _name : register(s##_slot)
#define PARAM_SAMPLER_2D_ARRAY_TYPED(_name, _type) extern sampler _name
#define PARAM_SAMPLER_2D_ARRAY_FIXED_TYPED(_name, _slot, _type) extern sampler _name : register(s##_slot)

// Global constants

#ifdef VERTEX_SHADER
	#define VERTEX_CONSTANT(type, name, register_index)   type name : register(register_index);
	#define PIXEL_CONSTANT(type, name, register_index)   type name;
	#define VERTEX_SAMPLER_CONSTANT(name, register_index) sampler2D name : register(register_index);
#else
	#define VERTEX_CONSTANT(type, name, register_index)   type name;
	#define PIXEL_CONSTANT(type, name, register_index)   type name : register(register_index);
	#define VERTEX_SAMPLER_CONSTANT(name, register_index)
#endif
#define BOOL_CONSTANT(name, register_index)   bool name : register(b##register_index);
#define INT_CONSTANT(name, register_index) int name : register(i##register_index);
#define SAMPLER_CONSTANT(name, register_index)	sampler name : register(s##register_index);
#define CONSTANT_NAME(n) c##n
#define BOOL_CONSTANT_NAME(n) b##n
#define INT_CONSTANT_NAME(n) i##n

#elif DX_VERSION == 11

#ifdef PARAM_ALLOC_PREPROCESS

	#define PARAM(_type, _name) ___PARAM___(_type _name)
	#define PARAM_ARRAY(_type, _name, _dim) ___PARAM___(_type _name _dim)
	#define PARAM_STRUCT(_type, _name) ___PARAM___(_type _name)
	#define PARAM_SAMPLER_2D_TYPED(_name, _type) ___SAMPLER___(2D _name)
	#define PARAM_SAMPLER_2D_FIXED_TYPED(_name, _slot, _type) ___SAMPLER___(2D _name _slot)
	#define PARAM_SAMPLER_3D_TYPED(_name, _type) ___SAMPLER___(3D _name)
	#define PARAM_SAMPLER_3D_FIXED_TYPED(_name, _slot, _type) ___SAMPLER___(3D _name _slot)
	#define PARAM_SAMPLER_CUBE_TYPED(_name, _type) ___SAMPLER___(CUBE _name)
	#define PARAM_SAMPLER_CUBE_FIXED_TYPED(_name, _slot, _type) ___SAMPLER___(CUBE _name _slot)
	#define PARAM_SAMPLER_2D_ARRAY_TYPED(_name, _type) ___SAMPLER___(2D_ARRAY _name)
	#define PARAM_SAMPLER_2D_ARRAY_FIXED_TYPED(_name, _slot, _type) ___SAMPLER___(2D_ARRAY _name _slot)

#elif defined(PARAM_ALLOC_FIRST_PASS)

	#define PARAM_STORAGE_float float4
	#define PARAM_STORAGE_float2 float4
	#define PARAM_STORAGE_float3 float4
	#define PARAM_STORAGE_float4 float4
	#define PARAM_STORAGE_int int4
	#define PARAM_STORAGE_bool bool

	#define PARAM(_type, _name) _type UserParameter_##_name; static _type _name = UserParameter_##_name
	#define PARAM_ARRAY(_type, _name, _dim) _type UserParameter_##_name _dim; static _type _name _dim = UserParameter_##_name
	#define PARAM_STRUCT(_type, _name) _type UserParameter_##_name; static _type _name = UserParameter_##_name

	#ifndef TEMP_SAMPLER_DECLARED
		#define TEMP_SAMPLER_DECLARED
		sampler TempSampler__;
	#endif

	#define DECLARE_PARAM_SAMPLER(_name, _texture_type, _return_type, _struct_type)					\
		_texture_type<_return_type> UserParameterTexture_##_name;									\
		static const _struct_type _name = { TempSampler__, UserParameterTexture_##_name }

	#define PARAM_SAMPLER_2D_TYPED(_name, _type) DECLARE_PARAM_SAMPLER(_name, texture2D, _type, texture_sampler_2d)
	#define PARAM_SAMPLER_2D_FIXED_TYPED(_name, _slot, _type) DECLARE_PARAM_SAMPLER(_name, texture2D, _type, texture_sampler_2d)
	#define PARAM_SAMPLER_3D_TYPED(_name, _type) DECLARE_PARAM_SAMPLER(_name, texture3D, _type, texture_sampler_3d)
	#define PARAM_SAMPLER_3D_FIXED_TYPED(_name, _slot, _type) DECLARE_PARAM_SAMPLER(_name, texture3D, _type, texture_sampler_3d)
	#define PARAM_SAMPLER_CUBE_TYPED(_name, _type) DECLARE_PARAM_SAMPLER(_name, TextureCube, _type, texture_sampler_cube)
	#define PARAM_SAMPLER_CUBE_FIXED_TYPED(_name, _slot, _type) DECLARE_PARAM_SAMPLER(_name, TextureCube, _type, texture_sampler_cube)
	#define PARAM_SAMPLER_2D_ARRAY_TYPED(_name, _type) DECLARE_PARAM_SAMPLER(_name, Texture2DArray, _type, texture_sampler_2d_array)
	#define PARAM_SAMPLER_2D_ARRAY_FIXED_TYPED(_name, _slot, _type) DECLARE_PARAM_SAMPLER(_name, Texture2DArray, _type, texture_sampler_2d_array)

#else

	#define PARAM(_type, _name) static _type _name = ___##_name
	#define PARAM_ARRAY(_type, _name, _dim) static _type _name _dim = ___##_name
	#define PARAM_STRUCT(_type, _name) static _type _name = ___##_name
	#define PARAM_SAMPLER_2D_TYPED(_name, _type)
	#define PARAM_SAMPLER_2D_FIXED_TYPED(_name, _slot, _type)
	#define PARAM_SAMPLER_3D_TYPED(_name, _type)
	#define PARAM_SAMPLER_3D_FIXED_TYPED(_name, _slot, _type)
	#define PARAM_SAMPLER_CUBE_TYPED(_name, _type)
	#define PARAM_SAMPLER_CUBE_FIXED_TYPED(_name, _slot, _type)
	#define PARAM_SAMPLER_2D_ARRAY_TYPED(_name, _type)
	#define PARAM_SAMPLER_2D_ARRAY_FIXED_TYPED(_name, _slot, _type)

#endif

#endif

#endif

#define PARAM_SAMPLER_2D(_name) PARAM_SAMPLER_2D_TYPED(_name, float4)
#define PARAM_SAMPLER_2D_FIXED(_name, _slot) PARAM_SAMPLER_2D_FIXED_TYPED(_name, _slot, float4)
#define PARAM_SAMPLER_3D(_name) PARAM_SAMPLER_3D_TYPED(_name, float4)
#define PARAM_SAMPLER_3D_FIXED(_name, _slot) PARAM_SAMPLER_3D_FIXED_TYPED(_name, _slot, float4)
#define PARAM_SAMPLER_CUBE(_name) PARAM_SAMPLER_CUBE_TYPED(_name, float4)
#define PARAM_SAMPLER_CUBE_FIXED(_name, _slot) PARAM_SAMPLER_CUBE_FIXED_TYPED(_name, _slot, float4)
#define PARAM_SAMPLER_2D_ARRAY(_name) PARAM_SAMPLER_2D_ARRAY_TYPED(_name, float4)
#define PARAM_SAMPLER_2D_ARRAY_FIXED(_name, _slot) PARAM_SAMPLER_2D_ARRAY_FIXED_TYPED(_name, _slot, float4)
