//#line 1 "source\rasterizer\hlsl\cubemap_phi_blur.hlsl"

#include "hlsl_constant_globals.fx"
#include "hlsl_vertex_types.fx"
#include "explicit\cubemap_registers.fx"

//@generate screen

LOCAL_SAMPLER_CUBE(source_sampler, 0);

struct screen_output
{
	float4 position	:SV_Position;
	float2 texcoord	:TEXCOORD0;
};

screen_output default_vs(vertex_type IN)
{
	screen_output OUT;

	OUT.texcoord = IN.texcoord;
	OUT.position.xy= IN.position;
	OUT.position.zw= 1.0f;

	return OUT;
}

void direction_to_theta_phi(in float3 direction, out float theta, out float phi)
{
	theta= atan2(direction.y, direction.x);
	phi= acos(direction.z);
}

float3 theta_phi_to_direction(in float theta, float phi)
{
	float3 direction;
	float sin_phi;
//	sincos(phi, sin_phi, direction.z);				// direction.z= cos(phi)
//	sincos(theta, direction.y, direction.x);		// direction.x= sin(phi) * cos(theta);
//	direction.xy *= sin_phi;						// direction.y= sin(phi) * sin(theta);
	direction.z= cos(phi);
	direction.x= sin(phi) * cos(theta);
	direction.y= sin(phi) * sin(theta);
	return direction;
}

float4 sample_cube_map(float3 direction)
{
	direction.y= -direction.y;
	return sampleCUBE(source_sampler, direction);
}

float4 default_ps(screen_output IN) : SV_Target
{
	float2 sample0= IN.texcoord;

	float3 direction;
	direction= forward - (sample0.y*2-1)*up - (sample0.x*2-1)*left;
	direction= direction * (1.0 / sqrt(dot(direction, direction)));

	float theta, phi;
	direction_to_theta_phi(direction, theta, phi);

	float4 color= 0.0f;

	color += 1   * sample_cube_map(theta_phi_to_direction(theta, phi - delta*5));
	color += 10  * sample_cube_map(theta_phi_to_direction(theta, phi - delta*4));
	color += 45  * sample_cube_map(theta_phi_to_direction(theta, phi - delta*3));
	color += 120 * sample_cube_map(theta_phi_to_direction(theta, phi - delta*2));
	color += 210 * sample_cube_map(theta_phi_to_direction(theta, phi - delta));
	color += 252 * sample_cube_map(direction);
	color += 210 * sample_cube_map(theta_phi_to_direction(theta, phi + delta));
	color += 120 * sample_cube_map(theta_phi_to_direction(theta, phi + delta*2));
	color += 45  * sample_cube_map(theta_phi_to_direction(theta, phi + delta*3));
	color += 10  * sample_cube_map(theta_phi_to_direction(theta, phi + delta*4));
	color += 1   * sample_cube_map(theta_phi_to_direction(theta, phi + delta*5));
	color *= (1/1024.0);

	return color;
}
