#ifndef _UBER_LIGHT_FX_
#define _UBER_LIGHT_FX_


void convert_uber_light_to_analytical_light(out float3 analytical_lighting_direction, out float3 analytical_lighting_intensity, float3 fragment_to_camera_world)
{
#ifdef SCOPE_LIGHTING
	float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
	
	
	if (k_ps_bool_is_uber_light_directional)
	{
		analytical_lighting_direction= k_ps_analytical_light_direction;
		analytical_lighting_intensity= k_ps_analytical_light_intensity;
	}
	else  // omni
	{	
		const float3 k_ps_omni_uber_light_position= k_ps_analytical_light_direction;
		
		float3 light_position= k_ps_omni_uber_light_position;
		
		analytical_lighting_direction= light_position - fragment_position_world;
		float lengthsq= dot(analytical_lighting_direction, analytical_lighting_direction);
		
		analytical_lighting_direction*= rsqrt(lengthsq);		// normalize
		
		analytical_lighting_intensity= k_ps_analytical_light_intensity;  // inverse of the square distance
	}
	
#endif
}

#endif //_UBER_LIGHT_FX_