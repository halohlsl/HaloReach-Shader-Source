// .custom is basically the same as .shader, except it doesn't support cook-torrance


#include "templated\templated_globals.fx"

#include "shared\utilities.fx"
#include "templated\deform.fx"
#include "shared\texture_xform.fx"

#include "templated\albedo.fx"
#include "templated\albedo_custom.fx"
#include "templated\parallax.fx"
#include "templated\bump_mapping.fx"
#include "templated\self_illumination.fx"
#include "templated\specular_mask.fx"
#include "templated\materials\material_models.fx"
#include "templated\environment_mapping.fx"
#include "templated\wetness.fx"
#include "shared\atmosphere.fx"
#include "templated\alpha_test.fx"
#include "templated\alpha_test_custom.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "shared\render_target.fx"
#include "shared\albedo_pass.fx"
#include "shared\blend.fx"

#include "shadows\shadow_generate.fx"

#include "templated\debug_modes.fx"
#include "templated\velocity.fx"

#include "templated\entry_points.fx"

