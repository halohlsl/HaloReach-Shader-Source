#ifndef _PARTICLE_PROPERTY_FX_
#define _PARTICLE_PROPERTY_FX_

// keep the index_ and bit_ #defines in sync!
#define _index_emitter_tint			0
#define _index_emitter_alpha		1
#define _index_emitter_size			2
#define _index_particle_color		3
#define _index_particle_intensity	4
#define _index_particle_alpha		5
#define _index_particle_scale		6
#define _index_particle_rotation	7
#define _index_particle_frame		8
#define _index_particle_black_point	9
#define _index_particle_aspect		10
#define _index_particle_self_acceleration 11
#define _index_particle_palette		12
#define _index_emitter_movement_turbulence 13
#define _index_max					14

#define _register_group_properties		3
#define _register_group_memexport		4

#define _dies_at_rest_bit					0 //_particle_dies_at_rest_bit
#define _dies_on_structure_collision_bit	1 //_particle_dies_on_structure_collision_bit
#define _dies_on_media_collision_bit		2 //_particle_dies_on_media_collision_bit
#define _dies_on_air_collision_bit			3 //_particle_dies_on_air_collision_bit
#define _has_sweetener_bit					4 //_particle_has_sweetener_bit

#define _randomly_flip_u_bit				0 //_particle_randomly_flip_u_bit
#define _randomly_flip_v_bit				1 //_particle_randomly_flip_v_bit
#define _random_starting_rotation_bit		2 //_particle_random_starting_rotation_bit
#define _tint_from_lightmap_bit				3 //_particle_tint_from_lightmap_bit
#define _tint_from_diffuse_texture_bit		4 //_particle_tint_from_diffuse_texture_bit
#define _source_bitmap_vertical_bit			5 //_particle_source_bitmap_vertical_bit
#define _intensity_affects_alpha_bit		6 //_particle_intensity_affects_alpha_bit
#define _fade_near_edge_bit					7 //_particle_fade_near_edge_bit
#define _motion_blur_bit					8 //_particle_motion_blur_bit
#define _double_sided_bit					9 //_particle_double_sided_bit
#define _fogged_bit							10//_particle_fogged_bit
#define _lightmap_lit_bit					11 //_particle_lightmap_lit_bit
#define _depth_fade_active_bit				12 //_particle_depth_fade_active_bit
#define _distortion_active_bit				13 //_particle_distortion_active_bit
#define _ldr_only_bit						14 //_particle_ldr_only_bit
#define _is_particle_model_bit				15 //_particle_is_particle_model_bit

#define _frame_animation_one_shot_bit		0 //_particle_frame_animation_one_shot_bit
#define _can_animate_backwards_bit			1 //_particle_can_animate_backwards_bit

#define _modifier_none			0
#define _modifier_add			1
#define _modifier_multiply		2

struct s_property
{
	float4 m_innards;
};

#endif
