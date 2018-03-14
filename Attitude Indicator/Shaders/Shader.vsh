//
//  Shader.vsh
//  Attitude Indicator
//
//  Created by Jose on 10/31/12.
//  Copyright (c) 2012 Jose. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;
//attribute vec4 color;
attribute vec2 texcoord;

varying vec4 s_colorVarying;
varying vec2 s_texCoord;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(1.0, 1.0, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    s_texCoord = texcoord; //
    s_colorVarying = nDotVP * diffuseColor;
    
    gl_Position = modelViewProjectionMatrix * position;
}
