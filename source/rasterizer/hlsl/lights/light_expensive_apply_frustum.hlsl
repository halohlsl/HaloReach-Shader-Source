////#line 1 "source\rasterizer\hlsl\light_apply_frustum.hlsl"
//@generate tiny_position
//@entry default

//###ctchou $TODO optimize this shader -- we should be able to drop it to 3 registers (it used to work with 3 registers in the old compiler..  boooo!)
//#define SHADER_ATTRIBUTES										[maxtempreg(3)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb)
#define LIGHT_COLOR												(light_colour_falloff_power.rgb)
#define DEFORM													deform_tiny_position_projective
#define USE_EXPENSIVE_MATERIAL

#include "lights\light_apply_base.hlsl"

