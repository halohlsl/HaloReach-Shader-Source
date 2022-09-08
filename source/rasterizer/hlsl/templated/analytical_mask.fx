#ifndef _ANALYTICAL_MASK_FX_
#define _ANALYTICAL_MASK_FX_

#ifdef VERTEX_SHADER

PARAM_SAMPLER_2D_FIXED(cloud_texture, 1);			// pixel shader

#else
	#ifdef IMPOSTER_CLOUD_SAMPLING
		#define cloud_texture k_ps_texture_cloud
	#else
	#ifdef SCOPE_LIGHTING
		#define cloud_texture analytical_gel
	#else
		PARAM_SAMPLER_2D(cloud_texture);  // won't be used
	#endif
	#endif
#endif

float2 get_analytical_mask_projected_texture_coordinate(float3 world_pos)
{
	float2 projected_coord=world_pos.xy-world_pos.z*v_analytical_light_direction.xy*v_analytical_light_direction.w;

	///  DESC: 3 Jul 2008   19:25 BUNGIE\yaohhu :
	///     without a correct texture, it returns 0 :(
	return projected_coord;
}

//#define cloud_scale (p_lightmap_compress_constant_0.y)
//#define cloud_offset (p_lightmap_compress_constant_0.zw)

float get_analytical_mask_from_projected_texture_coordinate(float2 coordinate, float lightmap_analytical_mask, float4 cloud_motion)
{
	float cloud_scale=cloud_motion.y;
	float2 cloud_offset=cloud_motion.zw;
#if !defined(pc) || (DX_VERSION == 11)
	float4 cloud=sample2Dlod( cloud_texture, coordinate*cloud_scale+cloud_offset, 0);

	return lightmap_analytical_mask*cloud.r;
#else
    return 1;
#endif
}

float3 transform_point_3x4(in float4 position, in float4 node[3])
{
	float3 result;

	result.x= dot(position, node[0]);
	result.y= dot(position, node[1]);
	result.z= dot(position, node[2]);

	return result;
}

float3 get_analytical_mask(float3 world_pos,float4 vmf_lighting_coefficients[4])
{
	float3 lightspace_pos=  transform_point_3x4(float4(world_pos,1), p_analytical_gel_xform);
#if !defined(pc) || (DX_VERSION == 11)
#ifdef SCOPE_LIGHTING

	float3 cloud;
	cloud= sample2D(cloud_texture, (lightspace_pos.z != 0) ? lightspace_pos.xy/lightspace_pos.z : 0);
	return vmf_lighting_coefficients[0].a*(1 - vmf_lighting_coefficients[2].a + cloud.rgb * vmf_lighting_coefficients[2].a);
#else
    return 1;
#endif
#else
    return 1;
#endif
}


#endif