#ifndef _DYNAMIC_LIGHT_CLIP_FX_
#define _DYNAMIC_LIGHT_CLIP_FX_

#include "shared\dynamic_light_clip_registers.fx"

#if DX_VERSION == 9

#define DYNAMIC_LIGHT_CLIP_OUTPUT
#define DYNAMIC_LIGHT_CLIP_OUTPUT_PARAM
#define DYNAMIC_LIGHT_CLIP_INPUT
#define DYNAMIC_LIGHT_CLIP_INPUT_PARAM
#define CALC_DYANMIC_LIGHT_CLIP(_screen_position)

#elif DX_VERSION == 11

struct s_dynamic_light_clip
{
	float4 distance_0123 : SV_ClipDistance0;
	float2 distance_45 : SV_ClipDistance1;
};

#define DYNAMIC_LIGHT_CLIP_OUTPUT out s_dynamic_light_clip clip,
#define DYNAMIC_LIGHT_CLIP_OUTPUT_PARAM clip,
#define DYNAMIC_LIGHT_CLIP_INPUT in s_dynamic_light_clip clip,
#define DYNAMIC_LIGHT_CLIP_INPUT_PARAM clip,
#define CALC_DYNAMIC_LIGHT_CLIP(_screen_position) 										\
	for (int i = 0; i < 4; i++)															\
	{																					\
		clip.distance_0123[i] = dot(_screen_position, v_dynamic_light_clip_plane[i]);	\
	}																					\
	for (int i = 4; i < 6; i++)															\
	{																					\
		clip.distance_45[i - 4] = dot(_screen_position, v_dynamic_light_clip_plane[i]);	\
	}

#endif

#endif
