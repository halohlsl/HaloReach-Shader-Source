#ifndef __CUI_HLSL_FX__
#define __CUI_HLSL_FX__

#define POSTPROCESS_COLOR

#include "hlsl_vertex_types.fx"

#ifndef CUI_USE_CUSTOM_VERTEX_SHADER
#define POSTPROCESS_USE_CUSTOM_VERTEX_SHADER
#endif	// !CUI_USE_CUSTOM_VERTEX_SHADER
#include "postprocess\postprocess.fx"

#include "explicit\cui_hlsl_registers.fx"

#ifndef CUI_USE_CUSTOM_VERTEX_SHADER
#include "explicit\cui_transform.fx"
#endif	// !CUI_USE_CUSTOM_VERTEX_SHADER

// Sample from a texture and return the result in premultiplied alpha form
float4 cui_tex2D(in sampler2D source_sampler, in float4 sampler_transform, in float2 texcoord)
{
	float4 color= tex2D(source_sampler, texcoord);

	// if transform.z is 0 then we need to multiply the rgb times the alpha for this texture
	color.rgb *= max(color.a, sampler_transform.z);
	
	// we need alpha to be inverted so that 1.0 is transparent.  Multiply-add a scale and an offset.
	color.a= color.a * sampler_transform.x + sampler_transform.y;
	
	return color;
}

// Sample from a texture and return the result in premultiplied alpha form,
// and also perform linear to gamma2 conversion
float4 cui_linear_to_gamma2_tex2D(in sampler2D source_sampler, in float4 sampler_transform, in float2 texcoord)
{
	float4 color= tex2D(source_sampler, texcoord);

	// if transform.z is 0 then we need to multiply the rgb times the alpha for this texture
	color.rgb = sqrt(color.rgb) * max(color.a, sampler_transform.z);
	
	// we need alpha to be inverted so that 1.0 is transparent.  Multiply-add a scale and an offset.
	color.a= color.a * sampler_transform.x + sampler_transform.y;
	
	return color;
}

// Sample from a texture and return the result in premultiplied alpha form
float4 cui_tex2D_secondary(in float2 texcoord)
{
	return cui_tex2D(source_sampler1, k_cui_sampler1_transform, texcoord);
}

// Sample from a texture and return the result in premultiplied alpha form
float4 cui_tex2D(in float2 texcoord)
{
	return cui_tex2D(source_sampler0, k_cui_sampler0_transform, texcoord);
}

// Sample from a texture and return the result in premultiplied alpha form
float4 cui_linear_to_gamma2_tex2D(in float2 texcoord)
{
	return cui_linear_to_gamma2_tex2D(source_sampler0, k_cui_sampler0_transform, texcoord);
}

// Multiply a premultiplied color by a non-premultipled tint color
float4 cui_tint(in float4 premultiplied, in float4 tint)
{
	float4 color;
	
	// multiply the color by the tint.  The tint isn't premultiplied so we need to do this here.
	color.rgb = premultiplied.rgb * tint.rgb * tint.a;

	// the tint color's alpha is 0 when transparent.  We need to invert our alpha, multiply by the tint color's 
	// alpha and flip the result.
	float non_premultiplied_alpha= tint.a * (1.0f - premultiplied.a); 
	color.a= 1.0f - non_premultiplied_alpha;

	return color;
}

// Multiply a premultiplied color by a non-premultipled tint color.  Same as 
// cui_tint(cui_tint(premultiplied, tint1), tint2) but slightly more efficient.
float4 cui_tint(in float4 premultiplied, in float4 tint1, in float4 tint2)
{
	float4 color;
	
	color.rgb= premultiplied.rgb * tint1.rgb * tint2.rgb * tint1.a * tint2.a;
	float non_premultiplied_alpha= tint1.a * tint2.a * (1.0f - premultiplied.a); 
	color.a= 1.0f - non_premultiplied_alpha;

	return color;
}

float4 cui_linear_to_gamma2(
	in float4 color)
{
	return float4(sqrt(color.rgb), color.a);
}

#endif // __CUI_HLSL_FX__
