//
//  Shader.fsh
//  Attitude Indicator
//
//  Created by Jose on 10/31/12.
//  Copyright (c) 2012 Jose. All rights reserved.
//

varying mediump vec4 s_colorVarying;
varying mediump vec2 s_texCoord;

uniform sampler2D texture;

void main()
{
    gl_FragColor = texture2D(texture, s_texCoord) * s_colorVarying;
    //gl_FragColor = s_colorVarying;

}
