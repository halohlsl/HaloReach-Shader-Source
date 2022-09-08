#if DX_VERSION == 11

CBUFFER_BEGIN(BlendParticleOverdrawVS)
	CBUFFER_CONST(BlendParticleOverdrawVS,	float4,	tile_scale_offset,	k_vs_blend_particle_overdraw_tile_scale_offset)
	CBUFFER_CONST(BlendParticleOverdrawVS,	float4,	quad_scale,			k_vs_blend_particle_overdraw_quad_scale)
CBUFFER_END

STRUCTURED_BUFFER(tile_buffer,	k_cs_blend_particle_overdraw_tile_buffer, uint2, 0)

#endif
