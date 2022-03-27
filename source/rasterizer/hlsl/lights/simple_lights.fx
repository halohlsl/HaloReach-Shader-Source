#ifndef _SIMPLE_LIGHTS_FX_
#define _SIMPLE_LIGHTS_FX_

/*
	simple lights are organized as an array of 16 structs consisting of 4 float4's
	
		position (xyz)		size (w)
		direction (xyz)		spherical % (w)
		color (xyz)			smooth (w)
		falloff scale (xy)	falloff offset (zw)
*/


#include "shared\constants.fx"

#ifndef SIMPLE_LIGHT_DATA
#define SIMPLE_LIGHT_DATA simple_lights
#define SIMPLE_LIGHT_COUNT simple_light_count
#endif // !SIMPLE_LIGHT_DATA


void calculate_simple_light(
		uniform int light_index,
		in float3 fragment_position_world,
		out float3 light_radiance,
		out float3 fragment_to_light)			// return normalized direction to the light
{
#ifdef dynamic_lights_use_array_notation
#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[light_index][(offset)].registers)
#else // XENON
#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[light_index + (offset)].registers)
#endif // XENON

#define		LIGHT_POSITION			LIGHT_DATA(0, xyz)
#define		LIGHT_DIRECTION			LIGHT_DATA(1, xyz)
#define		LIGHT_COLOR				LIGHT_DATA(2, xyz)
#define		LIGHT_SPHERE			LIGHT_DATA(1, w)
#define		LIGHT_SMOOTH			LIGHT_DATA(2, w)
#define		LIGHT_COSINE_CUTOFF_ANGLE LIGHT_DATA(3, x)
#define		LIGHT_ANGLE_FALLOFF_RAIO LIGHT_DATA(3, y)
#define		LIGHT_ANGLE_FALLOFF_POWER LIGHT_DATA(3, z)
#define		LIGHT_FAR_ATTENUATION_END LIGHT_DATA(4, y)
#define		LIGHT_FAR_ATTENUATION_RATIO LIGHT_DATA(4, z)
#define		LIGHT_BOUNDING_RADIUS	LIGHT_DATA(4, x)

	// calculate direction to light (4 instructions)
	fragment_to_light= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light
	float  light_dist2= dot(fragment_to_light, fragment_to_light);				// distance to the light, squared
	float distance= sqrt(light_dist2);
	fragment_to_light /= distance;									// normalized vector pointing to the light
		
	float2 falloff;
	falloff.x= saturate( (LIGHT_FAR_ATTENUATION_END  - distance) * LIGHT_FAR_ATTENUATION_RATIO) ; // distance based falloff				(2 instructions)
	falloff.x*=falloff.x;
	falloff.y= saturate( ( dot(fragment_to_light, LIGHT_DIRECTION) - LIGHT_COSINE_CUTOFF_ANGLE ) * LIGHT_ANGLE_FALLOFF_RAIO);
	falloff.y= pow(falloff.y, LIGHT_ANGLE_FALLOFF_POWER);
#ifdef pc
	falloff.y= abs(falloff.y);
#endif //pc
	// falloff.y= saturate(pow(falloff.y, LIGHT_SMOOTH) + LIGHT_SPHERE);						// smooth and add ambient				(4 instructions)
	float combined_falloff= falloff.x * falloff.y;								//										(1 instruction)

	light_radiance= LIGHT_COLOR * combined_falloff;								//										(1 instruction)
}

void calc_simple_lights_analytical_diffuse_only(
		in float3  fragment_position_world,
		in float3  surface_normal,
		out float3 diffusely_reflected_light)						// diffusely reflected light (not including diffuse surface color)
{
	diffusely_reflected_light= float3(0.0f, 0.0f, 0.0f);
	
	// add in simple lights
	#ifndef pc	
		[loop]
	#endif
	for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	{
		// Compute distance squared to light, to see if we can skip this light.
		// Note: This is also computed in calculate_simple_light below, but the shader
		// compiler will remove the second computation and share the results of this
		// computation.
		float3 fragment_to_light_test= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light
		float  light_dist2_test= dot(fragment_to_light_test, fragment_to_light_test);			// distance to the light, squared
		if( light_dist2_test >= LIGHT_BOUNDING_RADIUS )
		{
			// debug: use a strong green tint to highlight area outside of the light's radius
			//diffusely_reflected_light += float3( 0, 1, 0 );
			//specularly_reflected_light += float3( 0, 1, 0 );
			continue;
		}
		
		float3 fragment_to_light;
		float3 light_radiance;
		calculate_simple_light(
			light_index, fragment_position_world, light_radiance, fragment_to_light);
		
		// calculate diffuse cosine lobe (diffuse surface N dot L)
		float cosine_lobe= dot(surface_normal, fragment_to_light) + diffuse_light_cosine_raise;  // + 0.05 so that the grenade on the ground can work well.
		
		diffusely_reflected_light  += light_radiance * saturate(cosine_lobe) / pi;			// add light with cosine lobe (clamped positive)
		
		#ifdef pc
			if (light_index >= 7)		// god damn PC compiler likes to unroll these loops - only support 8 lights or so (:P)
			{
				light_index= 100;
			}
		#endif // pc
	}
}

void calc_simple_lights_analytical(
		in float3 fragment_position_world,
		in float3 surface_normal,
		in float3 view_reflect_dir_world,							// view direction = fragment to camera,   reflected around fragment normal
		in float specular_power,
		out float3 diffusely_reflected_light,						// diffusely reflected light (not including diffuse surface color)
		out float3 specularly_reflected_light)						// specularly reflected light (not including specular surface color)
{
	diffusely_reflected_light= float3(0.0f, 0.0f, 0.0f);
	specularly_reflected_light= float3(0.0f, 0.0f, 0.0f);
	
	// add in simple lights
#ifndef pc	
	[loop]
#endif
	for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	{
		// Compute distance squared to light, to see if we can skip this light.
		// Note: This is also computed in calculate_simple_light below, but the shader
		// compiler will remove the second computation and share the results of this
		// computation.
		float3 fragment_to_light_test= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light
		float  light_dist2_test= dot(fragment_to_light_test, fragment_to_light_test);				// distance to the light, squared
		if( light_dist2_test >= LIGHT_BOUNDING_RADIUS )
		{
			// debug: use a strong green tint to highlight area outside of the light's radius
			//diffusely_reflected_light += float3( 0, 1, 0 );
			//specularly_reflected_light += float3( 0, 1, 0 );
			continue;
		}
		
		float3 fragment_to_light;
		float3 light_radiance;
		calculate_simple_light(
			light_index, fragment_position_world, light_radiance, fragment_to_light);
		
		// calculate diffuse cosine lobe (diffuse surface N dot L)
		float cosine_lobe= dot(surface_normal, fragment_to_light) + diffuse_light_cosine_raise;  // + 0.05 so that the grenade on the ground can work well.
		
		diffusely_reflected_light  += light_radiance * saturate(cosine_lobe) / pi;			// add light with cosine lobe (clamped positive)
		
		// step(0.0f, cosine_lobe)
		//specularly_reflected_light += light_radiance * pow(max(0.0f, dot(fragment_to_light, view_reflect_dir_world)), specular_power);
		float specular_cosine_lobe= saturate(dot(fragment_to_light, view_reflect_dir_world));
		specularly_reflected_light += light_radiance * pow(specular_cosine_lobe, specular_power);
#ifdef pc
		if (light_index >= 7)		// god damn PC compiler likes to unroll these loops - only support 8 lights or so (:P)
		{
			light_index= 100;
		}
#endif // pc
	}
	specularly_reflected_light *= (1+specular_power);
}



float calc_diffuse_lobe(
	in float3 fragment_normal,
	in float3 fragment_to_light,
	in float3 translucency)
{
	// calculate diffuse cosine lobe (diffuse surface N dot L)
	float cosine_lobe= dot(fragment_normal, fragment_to_light);
	return saturate(cosine_lobe);
}


float calc_diffuse_translucent_lobe(
	in float3 fragment_normal,
	in float3 fragment_to_light,
	in float3 translucency)
{
	// calculate diffuse cosine lobe (diffuse surface N dot L)
	float cosine_lobe= dot(fragment_normal, fragment_to_light);
	float translucent_cosine_lobe= (cosine_lobe * translucency.x + translucency.y) * cosine_lobe + translucency.z;
	return translucent_cosine_lobe;
}


void calc_simple_lights_analytical_diffuse_translucent(
		in float3 fragment_position_world,
		in float3 surface_normal,
		in float3 translucency,
		out float3 diffusely_reflected_light)						// specularly reflected light (not including specular surface color)
{
	diffusely_reflected_light= float3(0.0f, 0.0f, 0.0f);
	
	// add in simple lights
#ifndef pc	
	[loop]
#endif
	for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	{
		// Compute distance squared to light, to see if we can skip this light.
		// Note: This is also computed in calculate_simple_light below, but the shader
		// compiler will remove the second computation and share the results of this
		// computation.
		float3 fragment_to_light_test= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light
		float  light_dist2_test= dot(fragment_to_light_test, fragment_to_light_test);				// distance to the light, squared
		if( light_dist2_test >= LIGHT_BOUNDING_RADIUS )
		{
			// debug: use a strong green tint to highlight area outside of the light's radius
			//diffusely_reflected_light += float3( 0, 1, 0 );
			//specularly_reflected_light += float3( 0, 1, 0 );
			continue;
		}
		
		float3 fragment_to_light;
		float3 light_radiance;
		calculate_simple_light(
			light_index, fragment_position_world, light_radiance, fragment_to_light);
				
		diffusely_reflected_light  += light_radiance * calc_diffuse_translucent_lobe(surface_normal, fragment_to_light, translucency);
		
#ifdef pc
		if (light_index >= 7)		// god damn PC compiler likes to unroll these loops - only support 8 lights or so (:P)
		{
			light_index= 100;
		}
#endif // pc
	}
}

#endif //_SIMPLE_LIGHTS_FX_