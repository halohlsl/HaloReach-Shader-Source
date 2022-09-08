#include "hlsl_constant_globals.fx"
#include "effects\write_particle_overdraw_args_registers.fx"

#ifdef durango

//@compute_shader

[numthreads(1, 1, 1)]
void default_cs()
{
	uint count = __XB_GDS_Read_U32(0);
	args_buffer[0] = 4;
	args_buffer[1] = count;
	args_buffer[2] = 0;
	args_buffer[3] = 0;
}

#endif
