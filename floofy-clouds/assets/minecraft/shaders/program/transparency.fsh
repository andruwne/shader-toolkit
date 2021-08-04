#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ItemEntitySampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;

#define NUM_LAYERS 6

// Layer struct to add blending mode
struct Layer
{
    vec4 color;
    int mode;
};

Layer color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
int index_layers[NUM_LAYERS] = int[NUM_LAYERS](0, 1 ,2, 3, 4, 5);
int active_layers = 0;

out vec4 fragColor;

void try_insert( vec4 color, int mode, sampler2D dSampler ) {
    if ( color.a == 0.0 ) {
        return;
    }

    float depth = texture( dSampler, texCoord ).r;
    color_layers[active_layers] = Layer(color, mode);
    depth_layers[active_layers] = depth;

    int jj = active_layers++;
    int ii = jj - 1;
    while ( jj > 0 && depth > depth_layers[index_layers[ii]] ) {
        int indexTemp = index_layers[ii];
        index_layers[ii] = index_layers[jj];
        index_layers[jj] = indexTemp;

        jj = ii--;
    }
}

vec3 blend( vec3 dst, vec4 src ) {
    return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

void main() {
    color_layers[0] = Layer(vec4( texture( DiffuseSampler, texCoord ).rgb, 1.0 ), 0);
    depth_layers[0] = texture( DiffuseDepthSampler, texCoord ).r;
    active_layers = 1;

    try_insert( texture( CloudsSampler, texCoord ),      1, CloudsDepthSampler);
    try_insert( texture( TranslucentSampler, texCoord ), 0, TranslucentDepthSampler);
    try_insert( texture( ParticlesSampler, texCoord ),   0, ParticlesDepthSampler);
    try_insert( texture( WeatherSampler, texCoord ),     0, WeatherDepthSampler);
    try_insert( texture( ItemEntitySampler, texCoord ),  0, ItemEntityDepthSampler);
    
    vec3 texelAccum = color_layers[index_layers[0]].color.rgb;
    for ( int ii = 1; ii < active_layers; ++ii ) {
        Layer l = color_layers[index_layers[ii]];

        // Choose between default blend and mix
        if (l.mode == 0) {
            texelAccum = blend( texelAccum, l.color);
        } else {
            texelAccum = mix(texelAccum, l.color.rgb, l.color.a);
        }
    }

    fragColor = vec4( texelAccum.rgb, 1.0 );
}