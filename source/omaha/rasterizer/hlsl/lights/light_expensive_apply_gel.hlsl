////#line 1 "source\rasterizer\hlsl\light_apply_gel.hlsl"
//@generate tiny_position
//@entry default

//###ctchou $TODO optimize this shader -- we should be able to drop it to 3 registers (it used to work with 3 registers in the old compiler..  boooo!)
//#define SHADER_ATTRIBUTES										[maxtempreg(4)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb)
#define LIGHT_COLOR												(light_colour_falloff_power.rgb * sampleCUBE(gel_sampler_cube, light_to_fragment_lightspace.xyz).rgb)
#define DEFORM													deform_tiny_position
#define USE_EXPENSIVE_MATERIAL

#include "lights\light_apply_base.hlsl"

