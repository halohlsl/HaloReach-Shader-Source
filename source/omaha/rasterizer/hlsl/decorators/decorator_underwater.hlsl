// decorator shader is defined as 'world' vertex type, even though it really doesn't have a vertex type - it does its own custom vertex fetches
//@generate decorator

#define DECORATOR_WAVY
#define DECORATOR_DYNAMIC_LIGHTS
#define PER_PLACEMENT_LIGHTING

#include "decorators\decorators.hlsl"
