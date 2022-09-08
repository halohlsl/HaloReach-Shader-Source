////#line 1 "source\rasterizer\hlsl\light_apply_frustum_specular_gel.hlsl"
//@generate tiny_position
//@entry default
//@entry albedo
//@entry active_camo

//#define SHADER_ATTRIBUTES										[maxtempreg(7)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb + specular_lobe * albedo.a)
#define LIGHT_COLOR												(light_colour_falloff_power.rgb * sample2D(gel_sampler, light_to_fragment_lightspace.yx / light_to_fragment_lightspace.z).rgb)
#define DEFORM													deform_tiny_position_projective


#include "lights\light_apply_base.hlsl"

