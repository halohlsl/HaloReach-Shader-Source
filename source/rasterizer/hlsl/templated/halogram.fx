// .halogram is basically the same as .shader, except it has several hardcoded categories:
//      albedo                  as .shader
//      bump_mapping            NONE
//      alpha_test              NONE
//      specular_mask           NONE
//      material_model          NONE
//      environment_mapping     NONE
//      self_illumination       as .shader
//      blend_mode              as .shader
//      parallax                NONE
//      misc                    as .shader

#define calc_bumpmap_ps calc_bumpmap_off_ps

#define calc_alpha_test_ps calc_alpha_test_off_ps

#define calc_specular_mask_ps calc_specular_mask_no_specular_mask_ps

#define material_type none

#define envmap_type none

#define NO_WETNESS_EFFECT


#include "templated\templated_globals.fx"


#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"

#include "templated\albedo.fx"
#include "templated\parallax.fx"
#include "templated\warp.fx"
#include "templated\bump_mapping.fx"
#include "templated\self_illumination.fx"
#include "templated\specular_mask.fx"
#include "templated\materials\material_models.fx"
#include "templated\environment_mapping.fx"
#include "templated\wetness.fx"
#include "templated\alpha_test.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"

#include "shared\atmosphere.fx"

#include "templated\self_illumination_halogram.fx"

#include "shadows\shadow_generate.fx"
#include "shadows\shadow_mask.fx"

#include "templated\debug_modes.fx"

#include "templated\overlays.fx"

#include "templated\active_camo.fx"

#include "templated\velocity.fx"


#include "templated\entry_points.fx"

