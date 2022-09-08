#if DX_VERSION == 9

DECLARE_PARAMETER(float4, local_depth_constants, c100);		// ###ctchou $TODO is this the same as the global depth constants?

#elif DX_VERSION == 11

CBUFFER_BEGIN(SSAOLocalDepthPS)
	CBUFFER_CONST(SSAOLocalDepthPS,		float4, 	local_depth_constants, 		k_ps_ssao_local_depth_constants)
CBUFFER_END

#endif
