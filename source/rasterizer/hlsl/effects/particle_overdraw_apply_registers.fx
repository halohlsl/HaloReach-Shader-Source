#if DX_VERSION == 11

CBUFFER_BEGIN(BlendParticleOverdraw)
	CBUFFER_CONST(BlendParticleOverdraw,	float4,	tile_scale_offset,	k_blend_particle_overdraw_tile_scale_offset)
	CBUFFER_CONST(BlendParticleOverdraw,	float4,	quad_scale,			k_blend_particle_overdraw_quad_scale)
	CBUFFER_CONST(BlendParticleOverdraw,	float4,	overdraw_size,		k_blend_particle_overdraw_size)
	CBUFFER_CONST(BlendParticleOverdraw,	uint,	cmask_pitch,		k_blend_particle_overdraw_cmask_pitch)
	CBUFFER_CONST(BlendParticleOverdraw,	uint3,	cmask_pitch_pad,	k_blend_particle_overdraw_cmask_pitch_pad)
CBUFFER_END

STRUCTURED_BUFFER(tile_buffer,		k_vs_blend_particle_overdraw_tile_buffer,				uint2,	0)
BUFFER(cmask_buffer, 				k_ps_blend_particle_overdraw_cmask_buffer, 	uint,	32)

#endif
