////#line 1 "source\rasterizer\hlsl\light_apply_frustum_specular.hlsl"
//@generate tiny_position
//@entry default
//@entry albedo

//#define SHADER_ATTRIBUTES										[maxtempreg(4)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb + specular_lobe * albedo.a)
#define LIGHT_COLOR												(p_lighting_constant_4.rgb)
#define DEFORM													deform_tiny_position_projective


#include "lights\light_apply_base.hlsl"

