/*
PARTICLE.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

//This comment causes the shader compiler to be invoked for certain types
//@generate s_particle_vertex
//@generate s_particle_model_vertex

#define PARTICLE_RENDER_METHOD_DEFINITION 1

// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
// We could automatically prepend this to the shader file when doing generate-templates, hmmm...
#ifndef category_albedo
extern int category_albedo;
#endif
#ifndef category_blend_mode
extern int category_blend_mode;
#endif
#ifndef category_depth_fade
extern int category_depth_fade;
#endif
#ifndef category_lighting
extern int category_lighting;
#endif
#ifndef category_fog
extern int category_fog;
#endif
#ifndef category_specialized_rendering
extern int category_specialized_rendering;
#endif
#ifndef category_frame_blend
extern int category_frame_blend;
#endif
#ifndef category_self_illumination
extern int category_self_illumination;
#endif

extern float depth_fade_range : register(c80);

#include "effects\particle_render.fx"
#include "effects\particle_render_fast.fx"
