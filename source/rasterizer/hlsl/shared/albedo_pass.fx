


struct albedo_pixel
{
	float4 albedo_specmask : COLOR0;		// albedo color (RGB) + specular mask (A)
	float4 normal : COLOR1;					// normal (XYZ)
};



albedo_pixel convert_to_albedo_target(in float4 albedo, in float3 normal, in float normal_alpha_spec_type)
{
	albedo_pixel result;
	
	result.albedo_specmask= albedo;
	result.normal.xyz= normal * 0.5f + 0.5f;		// bias and offset to all positive
	result.normal.w= normal_alpha_spec_type;		// alpha channel for normal buffer (either blend factor, or specular type)
	
	return result;
}



