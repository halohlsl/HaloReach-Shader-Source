#ifndef _SPHERICAL_HARMONICS_FX_
#define _SPHERICAL_HARMONICS_FX_

// some common shared routines for calculating sh lighting
//
// 

#ifdef VERTEX_SHADER
sampler g_sample_vmf_diffuse_vs;
#else
sampler g_sample_vmf_diffuse;
#endif

sampler g_sample_vmf_1d;
sampler g_sample_zonal_rot_lut;
sampler g_sample_vmf_phong_specular; // linear/quadratic terms of the zonal projection of vMF

#define SH_ORDER_0
#define SH_ORDER_1
#define SH_ORDER_2
#define DOMINANT_LIGHT

#define SQRT3 1.73205080756

// PRT C0 default = 1 / 2 sqrt(pi)
#define PRT_C0_DEFAULT (0.28209479177387814347403972578039)
#define pi 3.14159265358979323846
#define sh_constants_direction_evaluation0 0.28209479177387814347415840517935   //(0.5f/sqrt(D3DX_PI))          //DC
#define sh_constants_direction_evaluation1 0.48860251190291992158659018158716   //(0.5f*sqrt(3/D3DX_PI))        //Linear
#define sh_constants_direction_evaluation2 1.0925484305920790705438453491384    //(0.5f*sqrt(15/D3DX_PI))       // Qadratic -2,-1,1,2
#define sh_constants_direction_evaluation3 0.94617469575756001809307913369254   //(0.25f*sqrt(5/D3DX_PI))*3     // Qadratic 0
#define sh_constants_direction_evaluation4 0.5462742152960395352719226745692    //SHConstants[2]/2
#define sh_constants_direction_evaluation5 0.31539156525252000603102637789751   //SHConstants[3]/3

#define sh_dc_square (sh_constants_direction_evaluation0*sh_constants_direction_evaluation0)

///  $TODO: 20 Jun 2008   16:22 BUNGIE\yaohhu :
///     Sh coefficents is written everywhere. Should use this table:
const float sh_constants_direction_evaluation[]=
{
    sh_constants_direction_evaluation0,
    sh_constants_direction_evaluation1,
    sh_constants_direction_evaluation2,
    sh_constants_direction_evaluation3,
    sh_constants_direction_evaluation4,
    sh_constants_direction_evaluation5,
};


float convertBandwidth2TextureCoord(float fFandWidth)
{
    return fFandWidth;
}

float vmf_diffuse(in float4 Y[2],in float3 vSurfNormal_in)
{	
    float2 dominant_coord=float2(dot(Y[0].xyz, vSurfNormal_in)*0.5+0.5,
        convertBandwidth2TextureCoord(Y[1].w));
	return tex2Dlod(
#ifdef VERTEX_SHADER
		g_sample_vmf_diffuse_vs,
#else
		g_sample_vmf_diffuse,
#endif
		float4(dominant_coord,0,0)).a;
}	

float3 dual_vmf_diffuse(float3 normal, float4 lighting_constants[4])
{	
    float4 dom[2]={lighting_constants[0],lighting_constants[1]};
    float4 fil[2]={lighting_constants[2],lighting_constants[3]};
    float vmf_coeff_dom= vmf_diffuse(dom,normal);
    float vmf_coeff_fil= 0.25f;  // based on spherical harmonic or numerical integration
    
    float3 vmf_lighting=vmf_coeff_dom*
        lighting_constants[1].rgb+
        vmf_coeff_fil*
        lighting_constants[3].rgb;    
    return vmf_lighting/pi;
}	

void calc_prt_ravi_diff(
	in float prt_c0,
	in float3 vertex_normal,
	out float4 prt_ravi_diff)
{
	prt_ravi_diff= 1.0f;
	prt_ravi_diff.xz= prt_c0 / PRT_C0_DEFAULT;		// diffuse and specular occlusion	
	prt_ravi_diff.w= min(dot(vertex_normal, v_analytical_light_direction), prt_ravi_diff.x);		// specular (vertex N) dot L (kills backfacing specular)
}	
#endif
