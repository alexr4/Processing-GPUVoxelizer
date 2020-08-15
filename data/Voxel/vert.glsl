#version 430

uniform mat4 modelviewMatrix;
uniform mat3 normalMatrix;
uniform mat4 transform;
uniform float time;
uniform vec2 mouse;

in vec4 vertex;
in vec4 normal;
in vec4 color;
in vec4 offset;
in vec4 scale;

out vec4 vertColor;
out vec4 backVertColor;
out vec3 ecNormal;
out vec4 ecVertex;

out vec4 vambient;
out vec4 vspecular;
out vec4 vemissive;
out float vshininess;


void main(){
    vec4 position = vec4(vertex.xyz * scale.xyz + offset.xyz, 1.0);
    
    gl_Position = transform * position;
  
    //Define ecNormal & ecVertex
    ecNormal = normalize(normalMatrix * normal.xyz);
    ecVertex = modelviewMatrix * position;

    vertColor = color;
    backVertColor = vec4(0.0);

    vambient = vec4(1.0);
    vspecular = vec4(vec3(0.5), 1.0);
    vemissive = vec4(vec3(0.0), 1.0);
    vshininess = 1.0;
}