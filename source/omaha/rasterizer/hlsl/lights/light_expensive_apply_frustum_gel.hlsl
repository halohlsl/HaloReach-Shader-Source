////#line 1 "source\rasterizer\hlsl\light_apply_frustum_gel.hlsl"
//@generate tiny_position
//@entry default

//#define SHADER_ATTRIBUTES										[maxtempreg(6)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb)
#define LIGHT_COLOR												(light_colour_falloff_power.rgb * sample2D(gel_sampler, light_to_fragment_lightspace.yx / light_to_fragment_lightspace.z).rgb)
#define DEFORM													deform_tiny_position_projective
#define USE_EXPENSIVE_MATERIAL

#include "lights\light_apply_base.hlsl"

