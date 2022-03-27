//#line 2 "source\rasterizer\hlsl\bilateral_vertical.hlsl"


#include "hlsl_vertex_types.fx"
#include "shared\utilities.fx"
#include "postprocess\postprocess.fx"
//@generate screen


sampler2D source_sampler : register(s0);
PIXEL_CONSTANT(float4, kernel[5], POSTPROCESS_EXTRA_PIXEL_CONSTANT_0);		// 5 tap kernel, (x offset, y offset, weight),  offsets should be premultiplied by pixel_size


float distance_weight(float delta) 
{ 
	float sigma=	8.0f; 
//	return exp(-(delta*delta)/(2*sigma*sigma));			// gaussian distribution
	return saturate(1.0f - abs(delta) / sigma);				// triangle filter
} 


float photometric_weight(float delta) 
{ 
	float sigma=	0.02f;
//	return exp(-(delta*delta)/(2*sigma*sigma));			// gaussian distribution
	return saturate(1.0f - abs(delta) / sigma);				// triangle filter
} 


float4 default_ps(screen_output IN) : COLOR
{
	float2 texcoord=		IN.texcoord;
	float4 weighted_sum=	0.0f; 
	float total_weight=		0.0f; 

	float center_pixel = tex2D(source_sampler, texcoord);

	for (int i = 0; i < 17; i++) 
	{
		float location_delta=	i-8.0f;
		float4 sample=			tex2D(source_sampler, texcoord + float2(0.0f, location_delta) * pixel_size.xy);
		float intensity_delta=	sample - center_pixel;

		float weight = distance_weight(location_delta) * photometric_weight(intensity_delta); 
		
		weighted_sum	+= weight * sample; 
		total_weight	+= weight; 
	} 

	return weighted_sum/total_weight;
}
