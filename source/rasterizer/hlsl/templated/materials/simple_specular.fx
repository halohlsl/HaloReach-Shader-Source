#ifndef _SIMPLE_COOK_TORRANCE_FX_
#define _SIMPLE_COOK_TORRANCE_FX_

//****************************************************************************
// Simple Cook Torrance Material Model parameters
//****************************************************************************
/*
float	diffuse_coefficient;								//how much to scale diffuse by
float	specular_coefficient;								//how much to scale specular by
float3	fresnel_color;										//reflectance at normal incidence
float	roughness;											//roughness
float	area_specular_contribution;							//scale the area sh contribution
float	analytical_specular_contribution;					//scale the analytical sh contribution
float	environment_map_specular_contribution;				//scale the environment map contribution
float	albedo_blend;										//how much to blend in the albedo color to fresnel f0
float3	specular_tint;

sampler material_texture;					//a texture that stores spatially varient parameters
float4	material_texture_transform;			//texture matrix

sampler g_sampler_cc0236;					//pre-integrated texture
sampler g_sampler_dd0236;					//pre-integrated texture
sampler g_sampler_c78d78;					//pre-integrated texture

#define A0_88         0.886226925f
#define A2_10         1.023326708f
#define A6_49         0.495415912f
*/
//*****************************************************************************
// Analytical Cook-Torrance for point light source only
//*****************************************************************************


//*****************************************************************************
// cook-torrance for area light source in SH space
//*****************************************************************************


#define c_view_z_shift 0.5f/32.0f
#define	c_roughness_shift 0.0f

#define SWIZZLE xyzw

void sh_glossy_sct_3(
	in float3 view_dir,
	in float3 view_normal,
	in float4 sh_0,
	in float4 sh_312[3],
	in float4 sh_457[3],
	in float4 sh_8866[3],
	in float r_dot_l,
	out float3 specular_part,
	out float3 diffuse_part,
	out float3 schlick_part)
{

	//do I want to expose these parameters?
	//build the local frame
	float3 rotate_z= normalize(view_normal);
	float3 rotate_x= normalize(view_dir - dot(view_dir, rotate_z) * rotate_z);
	float3 rotate_y= normalize(cross(rotate_z, rotate_x));
	
	//local view
	float2 view_lookup;
	float roughness= max(roughness * roughness, 0.15f);
	
    view_lookup= float2( dot(view_dir,rotate_x)+c_view_z_shift, roughness + c_roughness_shift);
   
	float4 cc_value;
	float4 dd_value;
	
    // bases: 0,2,3,6
    float4 c_value;
    float4 d_value;
    
    c_value= tex2D( g_sampler_cc0236, view_lookup ).SWIZZLE;
    d_value= tex2D( g_sampler_dd0236, view_lookup ).SWIZZLE;
    
    float4 quadratic_a, quadratic_b, sh_local;
    
    //0,2,3,6 
//	quadratic_a.xyz = (rotate_x.yyx * rotate_x.xzz - 2.0 * rotate_z.yyx * rotate_z.xzz + rotate_y.yyx * rotate_y.xzz)/SQRT3;
//	quadratic_b= float4(0.5f * rotate_x.x * rotate_x.x +
//						rotate_z.y * rotate_z.y +
//						0.5f *  rotate_y.x * rotate_y.x,

//						rotate_z.x * rotate_z.x +
//						0.5f * rotate_x.y * rotate_x.y +
//						0.5f * rotate_y.y * rotate_y.y,

//						rotate_x.z * rotate_x.z / 2.0f -
//						rotate_z.z * rotate_z.z +
//						rotate_y.z * rotate_y.z / 2.0f,
						
//						0.0f)/SQRT3;
					
	quadratic_a.xyz= rotate_z.yzx * rotate_z.xyz * (-SQRT3);
	quadratic_b= float4(rotate_z.xyz * rotate_z.xyz, 1.0f/3.0f) * 0.5f * (-SQRT3);
	
    sh_local.xyz= sh_rotate_023(
		0,
		rotate_x,
		rotate_z,
		sh_0,
		sh_312);
		
	sh_local.w= dot(quadratic_a.xyz, sh_457[0].xyz) + dot(quadratic_b.xyzw, sh_8866[0].xyzw);
		
	//c0236 dot L0236
    diffuse_part.r = dot( float3(A0_88, A2_10, A6_49), sh_local.xyw );
    sh_local*= float4(1.0f, r_dot_l, r_dot_l, r_dot_l);
    specular_part.r= dot( c_value, sh_local ); 
	schlick_part.r= dot( d_value, sh_local );

    sh_local.xyz= sh_rotate_023(
		1,
		rotate_x,
		rotate_z,
		sh_0,
		sh_312);
	
	sh_local.w= dot(quadratic_a.xyz, sh_457[1].xyz) + dot(quadratic_b.xyzw, sh_8866[1].xyzw);	
				
    diffuse_part.g = dot( float3(A0_88, A2_10, A6_49), sh_local.xyw );
    sh_local*= float4(1.0f, r_dot_l, r_dot_l, r_dot_l);
    specular_part.g= dot( c_value, sh_local );
	schlick_part.g= dot( d_value, sh_local );

    sh_local.xyz= sh_rotate_023(
		2,
		rotate_x,
		rotate_z,
		sh_0,
		sh_312);
		
	sh_local.w= dot(quadratic_a.xyz, sh_457[2].xyz) + dot(quadratic_b.xyzw, sh_8866[2].xyzw);	
		
    diffuse_part.b = dot( float3(A0_88, A2_10, A6_49), sh_local.xyw );
    sh_local*= float4(1.0f, r_dot_l, r_dot_l, r_dot_l);
    specular_part.b= dot( c_value, sh_local );
	schlick_part.b= dot( d_value, sh_local );

    // basis - 7
    c_value= tex2D( g_sampler_c78d78, view_lookup ).SWIZZLE;
	quadratic_a.xyz = rotate_x.xyz * rotate_z.yzx + rotate_x.yzx * rotate_z.xyz;
	quadratic_b.xyz = rotate_x.xyz * rotate_z.xyz;
	sh_local.rgb= float3(dot(quadratic_a.xyz, sh_457[0].xyz) + dot(quadratic_b.xyz, sh_8866[0].xyz),
						 dot(quadratic_a.xyz, sh_457[1].xyz) + dot(quadratic_b.xyz, sh_8866[1].xyz),
						 dot(quadratic_a.xyz, sh_457[2].xyz) + dot(quadratic_b.xyz, sh_8866[2].xyz));
    
    
    sh_local*= r_dot_l;

    //c7 * L7
    specular_part.rgb+= c_value.x*sh_local.rgb;
    //d7 * L7
    schlick_part.rgb+= c_value.z*sh_local.rgb;
    
   	//basis - 8
	quadratic_a.xyz = rotate_x.xyz * rotate_x.yzx - rotate_y.yzx * rotate_y.xyz;
	quadratic_b.xyz = 0.5f*(rotate_x.xyz * rotate_x.xyz - rotate_y.xyz * rotate_y.xyz);
	
	sh_local.rgb= float3(-dot(quadratic_a.xyz, sh_457[0].xyz) - dot(quadratic_b.xyz, sh_8866[0].xyz),
		-dot(quadratic_a.xyz, sh_457[1].xyz) - dot(quadratic_b.xyz, sh_8866[1].xyz),
		-dot(quadratic_a.xyz, sh_457[2].xyz) - dot(quadratic_b.xyz, sh_8866[2].xyz));
		
    sh_local*= r_dot_l;
    
    //c8 * L8
    specular_part.rgb+= c_value.y*sh_local.rgb;
    //d8 * L8
    schlick_part.rgb+= c_value.w*sh_local.rgb;
    
    
    schlick_part= schlick_part * 0.01f;
    diffuse_part= diffuse_part/3.1415926f;
                
}

#ifdef SHADER_30
void calc_material_model_cook_torrance_ps(
	in float3 v_view_dir,
	in float3 fragment_to_camera_world,
	in float3 v_view_normal,
	in float3 view_reflect_dir_world,
	in float4 sh_lighting_coefficients[4],
	in float3 v_view_light_dir,
	in float3 light_color,
	in float3 albedo_color,
	in float  specular_mask,
	in float2 texcoord,
	in float4 prt_ravi_diff,
	out float4 envmap_specular_reflectance_and_roughness,
	out float3 envmap_area_specular_only,
	out float3 specular_color,
	out float3 diffuse_color)
{
	// this function shuold not be used.
}
#else
void calc_material_model_cook_torrance_ps(
	in float3 v_view_dir,
	in float3 fragment_to_camera_world,
	in float3 v_view_normal,
	in float3 view_reflect_dir_world,
	in float4 sh_lighting_coefficients[4],
	in float3 v_view_light_dir,
	in float3 light_color,
	in float3 albedo_color,
	in float  specular_mask,
	in float2 texcoord,
	in float4 prt_ravi_diff,
	out float4 envmap_specular_reflectance_and_roughness,
	out float3 envmap_area_specular_only,
	out float3 specular_color,
	out float3 diffuse_color)
{
	diffuse_color= diffuse_in;
	specular_color= 0.0f;

	envmap_specular_reflectance_and_roughness.xyz=	environment_map_specular_contribution * specular_mask * specular_coefficient;
	envmap_specular_reflectance_and_roughness.w=	roughness;			// TODO: replace with whatever you use for roughness	

	envmap_area_specular_only= 1.0f;
}
#endif

#endif //ifndef _SH_GLOSSY_FX_