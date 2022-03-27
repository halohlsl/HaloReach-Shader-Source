////#line 1 "source\rasterizer\hlsl\light_apply_frustum_gel.hlsl"
//@generate tiny_position
//@entry default
//@entry albedo

//#define SHADER_ATTRIBUTES										[maxtempreg(6)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb)
#define LIGHT_COLOR												(p_lighting_constant_4.rgb * tex2D(gel_sampler, light_to_fragment_lightspace.yx / light_to_fragment_lightspace.z).rgb)
#define DEFORM													deform_tiny_position_projective


#include "lights\light_apply_base.hlsl"

