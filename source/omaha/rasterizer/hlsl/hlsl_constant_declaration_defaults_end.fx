
// clear all the defaulted macros

#ifdef VERTEX_FLOAT_DEFAULT
#undef VERTEX_FLOAT
#undef VERTEX_FLOAT_DEFAULT
#endif // VERTEX_FLOAT_DEFAULT

#ifdef VERTEX_INT_DEFAULT
#undef VERTEX_INT
#undef VERTEX_INT_DEFAULT
#endif // VERTEX_INT_DEFAULT

#ifdef VERTEX_BOOL_DEFAULT
#undef VERTEX_BOOL
#undef VERTEX_BOOL_DEFAULT
#endif // VERTEX_BOOL_DEFAULT

#ifdef VERTEX_SAMPLER_DEFAULT
#undef VERTEX_SAMPLER
#undef VERTEX_SAMPLER_DEFAULT
#endif // VERTEX_SAMPLER_DEFAULT

#ifdef VERTEX_FLOAT_FREE_FOR_SHADERS_DEFAULT
#undef VERTEX_FLOAT_FREE_FOR_SHADERS
#undef VERTEX_FLOAT_FREE_FOR_SHADERS_DEFAULT
#endif // VERTEX_FLOAT_FREE_FOR_SHADERS_DEFAULT


#ifdef PIXEL_FLOAT_DEFAULT
#undef PIXEL_FLOAT
#undef PIXEL_FLOAT_DEFAULT
#endif // PIXEL_FLOAT_DEFAULT

#ifdef PIXEL_INT_DEFAULT
#undef PIXEL_INT
#undef PIXEL_INT_DEFAULT
#endif // PIXEL_INT_DEFAULT

#ifdef PIXEL_BOOL_DEFAULT
#undef PIXEL_BOOL
#undef PIXEL_BOOL_DEFAULT
#endif // PIXEL_BOOL_DEFAULT

#ifdef PIXEL_SAMPLER_DEFAULT
#undef PIXEL_SAMPLER
#undef PIXEL_SAMPLER_DEFAULT
#endif // PIXEL_SAMPLER_DEFAULT

#ifdef PIXEL_FLOAT_FREE_FOR_SHADERS_DEFAULT
#undef PIXEL_FLOAT_FREE_FOR_SHADERS
#undef PIXEL_FLOAT_FREE_FOR_SHADERS_DEFAULT
#endif // PIXEL_FLOAT_FREE_FOR_SHADERS_DEFAULT


// clear all the platform-specific macros

#undef XE_VERTEX_FLOAT
#undef XE_VERTEX_INT
#undef XE_VERTEX_BOOL
#undef XE_VERTEX_SAMPLER
#undef XE_PIXEL_FLOAT
#undef XE_PIXEL_INT
#undef XE_PIXEL_BOOL
#undef XE_PIXEL_SAMPLER

#undef PC_VERTEX_FLOAT
#undef PC_VERTEX_INT
#undef PC_VERTEX_BOOL
#undef PC_VERTEX_SAMPLER
#undef PC_PIXEL_FLOAT
#undef PC_PIXEL_INT
#undef PC_PIXEL_BOOL
#undef PC_PIXEL_SAMPLER



#ifdef VERTEX_CONSTANT_DEFAULT
#undef VERTEX_CONSTANT
#undef VERTEX_CONSTANT_DEFAULT
#endif // VERTEX_CONSTANT_DEFAULT

#ifdef PIXEL_CONSTANT_DEFAULT
#undef PIXEL_CONSTANT
#undef PIXEL_CONSTANT_DEFAULT
#endif // PIXEL_CONSTANT_DEFAULT


#ifdef SHADER_CONSTANT_DEFAULT
#undef SHADER_CONSTANT
#undef SHADER_CONSTANT_DEFAULT
#endif // SHADER_CONSTANT_DEFAULT
