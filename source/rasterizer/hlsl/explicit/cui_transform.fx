#ifndef __CUI_TRANSFORM_FX__
#define __CUI_TRANSFORM_FX__

screen_output default_vs(
	vertex_type IN)
{
	screen_output OUT;

	OUT.texcoord= IN.texcoord;

	float4 position= float4(IN.position, 0.0F, 1.0F);
	float3 model_view_position= mul(position, k_cui_vertex_shader_constant_model_view_matrix);
	OUT.position= mul(float4(model_view_position, 1.0F), k_cui_vertex_shader_constant_projection_matrix);
	
	OUT.color= IN.color;

	return OUT;
}

#endif	// __CUI_TRANSFORM_FX__

