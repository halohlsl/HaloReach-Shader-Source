#if DX_VERSION == 11

CBUFFER_BEGIN(CopyParticleOverdrawCMaskToHiStencil)
	CBUFFER_CONST(CopyParticleOverdrawCMaskToHiStencil,		uint,		max_index,		k_cs_copy_particle_overdraw_cmask_to_histencil_max_index)
	CBUFFER_CONST(CopyParticleOverdrawCMaskToHiStencil,		uint,		cmask_width,	k_cs_copy_particle_overdraw_cmask_to_histencil_cmask_width)
	CBUFFER_CONST(CopyParticleOverdrawCMaskToHiStencil,		uint,		cmask_pitch,	k_cs_copy_particle_overdraw_cmask_to_histencil_cmask_pitch)
	CBUFFER_CONST(CopyParticleOverdrawCMaskToHiStencil,		uint,		htile_pitch,	k_cs_copy_particle_overdraw_cmask_to_histencil_htile_pitch)
CBUFFER_END

BUFFER(cmask_buffer, 	k_cs_copy_particle_overdraw_cmask_to_histencil_cmask_buffer, uint, 0)
RW_BUFFER(htile_buffer, k_cs_copy_particle_overdraw_cmask_to_histencil_htile_buffer, uint, 0)

#define CS_PARTICLE_OVERDRAW_CMASK_TO_HISTENCIL_THREADS 64

#endif
