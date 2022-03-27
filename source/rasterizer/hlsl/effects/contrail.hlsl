/*
CONTRAIL.FX
Copyright (c) Microsoft Corporation, 2005. all rights reserved.
04/12/2006 13:36 davcook	
*/

//This comment causes the shader compiler to be invoked for certain types
//@generate s_contrail_vertex

#define CONTRAIL_RENDER_METHOD_DEFINITION 1

// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

// If the categories are not defined by the preprocessor, treat them as shader constants set by the game.
#ifndef category_albedo
extern int category_albedo;
#endif
#ifndef category_blend_mode
extern int category_blend_mode;
#endif
#ifndef category_fog
extern int category_fog;
#endif

#ifndef PIXEL_SHADER

// vertex shader needs to handle all cases including transparent:
#define SCOPE_TRANSPARENTS

#endif


#include "effects\contrail_render.hlsl"
