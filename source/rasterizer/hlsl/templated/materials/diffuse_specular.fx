#ifndef _DIFFUSE_SPECULAR_H_
#define _DIFFUSE_SPECULAR_H_

#include "shared\spherical_harmonics.fx"

#if 1
PARAM_SAMPLER_2D_ARRAY(g_diffuse_power_specular);
#else
#define g_diffuse_power_specular g_sample_vmf_diffuse
#endif

float vmf_diffuse_specular(in float4 Y[2], in float3 vSurfNormal_in,float roughness)
{
    float3 coord=float3(dot(Y[0].xyz, vSurfNormal_in)*0.5+0.5,
                        convertBandwidth2TextureCoord(Y[1].w),
                        roughness);

#if DX_VERSION == 9
    float texture_sample=sample3D(g_diffuse_power_specular,coord).r;
#elif DX_VERSION == 11
	float4 specular_texcoord = convert_3d_texture_coord_to_array_texture(g_diffuse_power_specular, coord.xyz);
	float texture_sample = lerp(
		g_diffuse_power_specular.t.Sample(g_diffuse_power_specular.s, specular_texcoord.xyz).r,
		g_diffuse_power_specular.t.Sample(g_diffuse_power_specular.s, specular_texcoord.xyw).r,
		frac(specular_texcoord.z));
#endif

    //assert(texture_sample!=1);

	return texture_sample * 3; // normalized to [0,1], it should be [0,3]
}

float3 dual_vmf_diffuse_specular(float3 reflected_dir, float4 lighting_constants[4],float roughness)
{
    float4 dom[2]={lighting_constants[0],lighting_constants[1]};
    float4 fil[2]={lighting_constants[2],lighting_constants[3]};

    float vmf_specular_dom= vmf_diffuse_specular(dom, reflected_dir, roughness);
    float vmf_specular_fil= 0.25f;
    return  vmf_specular_dom * lighting_constants[1].rgb +
           vmf_specular_fil * lighting_constants[3].rgb;
}


void dual_vmf_diffuse_specular_with_fresnel(
	in float3 view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float4 lighting_constants[4],
	in float3 final_specular_color,							// diffuse reflectance (ignored for cook-torrance)
	in float specular_power,
	out float3 sh_glossy)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
{
    float3 view_reflect_dir=reflect(-view_dir,normal_dir);

    float3 vmf_specular=
        //dual_vmf_diffuse(view_reflect_dir, lighting_constants);
        dual_vmf_diffuse_specular(view_reflect_dir,lighting_constants,specular_power);

    sh_glossy=final_specular_color*vmf_specular;
}


#endif //_DIFFUSE_SPECULAR_H_