//#line 2 "source\rasterizer\hlsl\shadow_apply_bilinear.hlsl"

//@generate tiny_position

#if !defined(pc) || (DX_VERSION == 11)
#define BILINEAR_SHADOWS
#endif // pc

#define FASTER_SHADOWS

#include "shadows\shadow_apply.hlsl"
