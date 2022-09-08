
#ifndef __ATMOSPHERE_FX_H__
#define __ATMOSPHERE_FX_H__


// this file is only used by vertex shader of transparent meshes

// ------------- use global_render constants for atmosphere constants

#define FOG_ENABLED
	#include "shared\atmosphere_core.fx"
	#include "shared\atmosphere_registers.fx"
#undef FOG_ENABLED


#if defined(xenon) || (DX_VERSION == 11)
	#ifndef BLEND_MODE_OFF
		#define FOG_ENABLED
	#endif // !BLEND_MODE_OFF
#endif //xenon


#if defined(VERTEX_SHADER) && defined(FOG_ENABLED)

#define _planar_fog_color			k_vs_planar_fog_constant_0.xyz
#define _planar_fog_thickness		k_vs_planar_fog_constant_0.w
#define _planar_fog_plane_coeffs	k_vs_planar_fog_constant_1

void compute_scattering(			// vertex shader
		in float3 view_point,
		in float3 scene_point,
		out float3 inscatter,
		out float extinction)
{

		float4 fog_parameters= get_atmosphere_fog_optimized_LUT(
					k_vs_sampler_atm_fog_table,
					k_vs_LUT_constants,
					k_vs_fog_constants,
					Camera_Position,
					scene_point,
					k_vs_boolean_enable_atm_fog,
					true);

		inscatter= fog_parameters.rgb;
		extinction= fog_parameters.a;

		// calculate planar fog
		#ifdef VERTEX_SHADER
			[branch]
			if (_planar_fog_thickness > 0)
			{
				float planar_fog_scene_depth= dot(_planar_fog_plane_coeffs, float4(scene_point, 1.0f));
				float planar_fog_view_depth= dot(_planar_fog_plane_coeffs, float4(view_point, 1.0f));

				// ignore soften fog effect for VS, because we are out of constant registers

				float extinction_in_planar_fog= compute_extinction(_planar_fog_thickness, planar_fog_scene_depth);
				float3 inscatter_in_planar_fog= (1.0f - extinction_in_planar_fog) * _planar_fog_color;

				if (planar_fog_view_depth > 0)
				{
					inscatter= inscatter*extinction_in_planar_fog + inscatter_in_planar_fog;
				}
				else
				{
					inscatter+= extinction*inscatter_in_planar_fog;
				}
				extinction*= extinction_in_planar_fog;
			}
		#endif	// VERTEX_SHADER

}

#else // !FOG_ENABLED

void compute_scattering(
	in float3 view_point,
	in float3 scene_point,
	out float3 inscatter,
	out float extinction)
{
	extinction=		1.0f;
	inscatter=		0.0f;
}

#endif // FOG_ENABLED


#endif //__ATMOSPHERE_FX_H__