////#line 1 "source\rasterizer\hlsl\light_apply.hlsl"
//@generate tiny_position
//@entry default
//@entry albedo

//###ctchou $TODO optimize this shader -- we should be able to drop it to 3 registers (it used to work with 3 registers in the old compiler..  boooo!)
//#define SHADER_ATTRIBUTES										[maxtempreg(3)]
#define COMBINE_LOBES(cosine_lobe, specular_lobe, albedo)		(cosine_lobe * albedo.rgb)
#define LIGHT_COLOR												(p_lighting_constant_4.rgb)
#define DEFORM													deform_tiny_position


#include "lights\light_apply_base.hlsl"

