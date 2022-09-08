#ifndef _FOLIAGE_MATERIAL_DOT_PRODUCT_FX_
#define _FOLIAGE_MATERIAL_DOT_PRODUCT_FX_

///  DESC: 13 1 2009   11:52 BUNGIE\yaohhu :
#include "lights\simple_lights.fx"

float foliage_dot_product(float3 light_direction, float3 bump_normal, float translucency_input)
{
	float k=			1.0f - translucency_input;
	float k2=		k * k * 0.25f;
	float scale=		1.0f / (1 + k + k2);
	
	float temp =	((1.0f + k) * 0.5f) * scale;
	

	float3 translucency=float3(temp, k*temp, k2 * temp + (translucency_input) * 0.5f );
	
	return calc_diffuse_translucent_lobe(bump_normal, light_direction, translucency);
}


#endif // _FOLIAGE_MATERIAL_DOT_PRODUCT_FX_