// Uniforms
uniform mat4 u_worldViewMatrix;                     // Matrix to tranform a position to view space.
uniform mat4 u_worldViewProjectionMatrix;           // Matrix to transform a position to clip space.
uniform mat4 u_inverseTransposeWorldViewMatrix;     // Matrix to transform a normal to view space.
uniform vec3 u_cameraViewPosition;                      // Position of the camera.

// Inputs
attribute vec4 a_position;                          // Vertex Position (x, y, z, w)
attribute vec3 a_normal;                            // Vertex Normal (x, y, z)
attribute vec2 a_texCoord;                          // Vertex Texture Coordinate (u, v)
attribute vec3 a_tangent;                           // Vertex Tangent (x, y, z)
attribute vec3 a_binormal;                          // Vertex Binormal (actually Bi-tangent) (x, y, z)

// Outputs
varying vec2 v_texCoord;                            // Texture Coordinate (u,v)
varying vec3 v_cameraDirection;                     // Direction the camera is looking at in tangent space.



#ifdef MAXDIRLIGHT
struct DirectionLight
{
    vec3 dir;
    vec3 color;
};
#endif

#ifdef MAXPOINTLIGHT
struct PointLight
{
    vec3 position;
    vec3 color;
    float rangeInverse;
};
#endif

#ifdef MAXSPOTLIGHT
struct SpotLight
{
    vec3 position;
    vec3 color;
    float rangeInverse;
    vec3 dir;
    float innerAngleCos;
    float outerAngleCos;
};
#endif

#ifdef MAXDIRLIGHT
uniform DirectionLight u_dirlight[MAXDIRLIGHT];
#endif
#ifdef MAXPOINTLIGHT
uniform PointLight u_pointlight[MAXPOINTLIGHT];
#endif
#ifdef MAXSPOTLIGHT
uniform SpotLight u_spotlight[MAXSPOTLIGHT];
#endif

//uniform vec3 u_nlight; // light number, u_nlight.x directional light, u_nlight.y point light, u_nlight.z spot light
#ifdef OPENGL_ES
uniform lowp int u_ndirlight;
uniform lowp int u_npointlight;
uniform lowp int u_nspotlight;
#else
uniform int u_ndirlight;
uniform int u_npointlight;
uniform int u_nspotlight;
#endif

#ifdef MAXPOINTLIGHT
varying vec4 v_vertexToPointLightDirection[MAXPOINTLIGHT];
#endif
#ifdef MAXSPOTLIGHT
varying vec3 v_vertexToSpotLightDirection[MAXSPOTLIGHT];              // Light direction w.r.t current vertex.
varying float v_spotLightAttenuation[MAXSPOTLIGHT];                   // Attenuation of spot light.
varying vec3 v_spotLightDirection[MAXSPOTLIGHT]; 
#endif
#ifdef MAXDIRLIGHT
varying vec3 v_dirlightDirection[MAXDIRLIGHT];
#endif


#ifdef MAXPOINTLIGHT
void applyPointLight(mat3 tangentSpaceTransformMatrix)
{
    vec4 positionWorldViewSpace = u_worldViewMatrix * a_position;
    
    // Compute camera direction and transform it to tangent space.
    v_cameraDirection = tangentSpaceTransformMatrix * (u_cameraViewPosition - positionWorldViewSpace.xyz);
    
    for (int i = 0; i < u_npointlight; i++) 
	{
        // Compute the light direction with light position and the vertex position.
        vec3 lightDirection = u_pointlight[i].position - positionWorldViewSpace.xyz;
        
        // Transform current light direction to tangent space.
		vec4 vertexToPointLightDirection;       
        vertexToPointLightDirection.xyz = tangentSpaceTransformMatrix * lightDirection;

        // Attenuation       
        vertexToPointLightDirection.w = 1.0 - dot(lightDirection * u_pointlight[i].rangeInverse, lightDirection * u_pointlight[i].rangeInverse);
        vertexToPointLightDirection.w = clamp(vertexToPointLightDirection.w, 0.0, 1.0);

        // Output light direction.
        v_vertexToPointLightDirection[i] =  vertexToPointLightDirection;
    }
}
#endif


#ifdef MAXSPOTLIGHT
void applySpotLight(mat3 tangentSpaceTransformMatrix)
{
    vec4 positionWorldViewSpace = u_worldViewMatrix * a_position;
    
    // Compute camera direction and transform it to tangent space.
    v_cameraDirection = tangentSpaceTransformMatrix * (u_cameraViewPosition - positionWorldViewSpace.xyz);

    for (int i = 0; i < u_nspotlight; i++) 
	{
        // Transform spot light direction to tangent space.
        v_spotLightDirection[i] = tangentSpaceTransformMatrix * u_spotlight[i].dir;
        
        // Compute the light direction with light position and the vertex position.
        vec3 lightDirection = u_spotlight[i].position - positionWorldViewSpace.xyz;
        
        // Transform current light direction to tangent space.
        lightDirection = tangentSpaceTransformMatrix * lightDirection;
        
        // Attenuation
        v_spotLightAttenuation[i] = 1.0 - dot(lightDirection * u_spotlight[i].rangeInverse, lightDirection * u_spotlight[i].rangeInverse);
        v_spotLightAttenuation[i] = clamp(v_spotLightAttenuation[i], 0.0, 1.0);

        // Output light direction.
        v_vertexToSpotLightDirection[i] = lightDirection;
    }
    
}
#endif


#ifdef MAXDIRLIGHT
void applyDirLight(mat3 tangentSpaceTransformMatrix)
{
    vec4 positionWorldViewSpace = u_worldViewMatrix * a_position;
    
    // Compute camera direction and transform it to tangent space.
    v_cameraDirection = tangentSpaceTransformMatrix * (u_cameraViewPosition - positionWorldViewSpace.xyz);
    for (int i = 0; i < u_ndirlight; i++) 
	{
        // Transform light direction to tangent space.
        v_dirlightDirection[i] = tangentSpaceTransformMatrix * u_dirlight[i].dir;
    }
}

#endif

#include "skinned_bump.h"

void main()
{

    vec4 position = getPosition();
    vec3 normal = getNormal();
    vec3 tangent = getTangent();
    vec3 binormal = getBinormal();
	
	    
    // Transform position to clip space.
    gl_Position = u_worldViewProjectionMatrix * position;

    // Transform the normal, tangent and binormals to  view space.
    mat3 inverseTransposeWorldViewMatrix = mat3(u_inverseTransposeWorldViewMatrix[0].xyz,
                                                u_inverseTransposeWorldViewMatrix[1].xyz,
                                                u_inverseTransposeWorldViewMatrix[2].xyz);
    vec3 tangentVector  = normalize(inverseTransposeWorldViewMatrix * tangent);
    vec3 normalVector = normalize(inverseTransposeWorldViewMatrix * normal);
    vec3 binormalVector = normalize(inverseTransposeWorldViewMatrix * binormal);

    // Create a transform to convert a vector to tangent space.
    mat3 tangentSpaceTransformMatrix = mat3(tangentVector.x, binormalVector.x, normalVector.x,
                                            tangentVector.y, binormalVector.y, normalVector.y,
                                            tangentVector.z, binormalVector.z, normalVector.z);

    // Apply light.    
#ifdef MAXDIRLIGHT
    if (u_ndirlight > 0)
        applyDirLight(tangentSpaceTransformMatrix);
#endif
    
#ifdef MAXPOINTLIGHT
    if (u_npointlight > 0)
        applyPointLight(tangentSpaceTransformMatrix);
#endif
    
#ifdef MAXSPOTLIGHT
    if (u_nspotlight > 0)
        applySpotLight(tangentSpaceTransformMatrix);
#endif

    // Pass on the texture coordinates to Fragment shader.
    v_texCoord = a_texCoord;
}