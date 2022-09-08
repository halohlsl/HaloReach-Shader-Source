#ifndef _HUD_CAMERA_NIGHTVISION_REGISTERS_FX_
#ifndef DEFINE_CPP_CONSTANTS
#define _HUD_CAMERA_NIGHTVISION_REGISTERS_FX_
#endif

#if DX_VERSION == 9

float4 falloff : register(c94);
float4x4 screen_to_world : register(c95);
float4 ping : register(c99);
float4 colors[4][2] : register(c100);

#else

CBUFFER_BEGIN(HUDCameraNightVisionPS)
	CBUFFER_CONST(HUDCameraNightVisionPS,		float4,		falloff,			k_ps_camera_nightvision_falloff)
	CBUFFER_CONST(HUDCameraNightVisionPS,		float4x4,	screen_to_world,	k_ps_camera_nightvision_screen_to_world)
	CBUFFER_CONST(HUDCameraNightVisionPS,		float4,		ping,				k_ps_camera_nightvision_ping)
	CBUFFER_CONST_ARRAY(HUDCameraNightVisionPS,	float4,		colors,	[4][2],		k_ps_camera_nightvision_colors)
CBUFFER_END

#endif

#endif

