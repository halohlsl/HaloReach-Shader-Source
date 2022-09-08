#ifndef _HUD_CAMERA_MASK_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _HUD_CAMERA_MASK_REGISTERS_FX_
#endif

#if DX_VERSION == 9

float4 colors[4] : register(c100);

#elif DX_VERSION == 11

CBUFFER_BEGIN(HUDCameraMaskPS)
	CBUFFER_CONST_ARRAY(HUDCameraMaskPS,	float4,	colors,	[4],	k_ps_hud_camera_mask_colors)
CBUFFER_END

#endif

#endif

