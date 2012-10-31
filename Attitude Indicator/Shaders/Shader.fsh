//
//  Shader.fsh
//  Attitude Indicator
//
//  Created by Jose on 10/31/12.
//  Copyright (c) 2012 Jose. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
