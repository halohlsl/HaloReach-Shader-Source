
#ifndef _PC_LIGHTING_H_
#define _PC_LIGHTING_H_

//#line 1 "source\rasterizer\hlsl\pc_lighting.fx"


#ifdef pc

float4 debug_tint;
float3 calc_pc_albedo_lighting(
	in float3 albedo,
	in float3 normal)
{
	float3 light_direction1= float3(0.68f, 0.48f, -0.6f);
	float3 light_direction2= float3(-0.3f, -0.7f, -0.6f);
	
	float3 light_color1= float3(1.2f, 1.2f, 1.2f);
	float3 light_color2= float3(0.5f, 0.5f, 0.5f);
	float3 light_color3= float3(0.7f, 0.7f, 0.7f);
	float3 light_color4= float3(0.4f, 0.4f, 0.4f);
	
	float3 n_dot_l;
	
	n_dot_l= saturate(dot(normal, light_direction1))*light_color1;
	n_dot_l+= saturate(dot(normal, -light_direction1))*light_color2;
	n_dot_l+= saturate(dot(normal, light_direction2))*light_color3;
	n_dot_l+= saturate(dot(normal, -light_direction2))*light_color4;

	return(n_dot_l*albedo);
}

#endif // pc


void apply_pc_albedo_modifier(
	inout float4 albedo,
	in float3 normal)
{
#ifdef pc
	albedo.rgb= lerp(albedo.rgb, debug_tint.rgb, debug_tint.a);	
	if (p_shader_pc_albedo_lighting!=0.f)
	{
		albedo.xyz= calc_pc_albedo_lighting(albedo, normal);
	}
#else
	albedo= albedo;
	return;
#endif // pc
}

#endif