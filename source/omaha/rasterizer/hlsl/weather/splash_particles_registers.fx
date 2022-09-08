#if DX_VERSION == 9

#ifdef VERTEX_SHADER
sampler1D	splash_data_texture : register(s0);
#endif

#elif DX_VERSION == 11

#if defined(COMPUTE_SHADER) || defined(SPLASH_PARTICLE_BUFFER_UAV) || defined(DEFINE_CPP_CONSTANTS)
RW_STRUCTURED_BUFFER(g_splash_particle_buffer, k_splash_particle_buffer_uav, float4, 1)
#endif

#if ((!defined(COMPUTE_SHADER)) && (!defined(SPLASH_PARTICLE_BUFFER_UAV))) || defined(DEFINE_CPP_CONSTANTS)
STRUCTURED_BUFFER(g_splash_particle_buffer, k_splash_particle_buffer_srv, float4, 16)
#endif

#define CS_INITIALIZE_SPLASH_PARTICLES_THREADS 64
#define CS_UPDATE_SPLASH_PARTICLES_THREADS 64

#endif