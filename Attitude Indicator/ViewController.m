//
//  ViewController.m
//  Attitude Indicator
//
//  Created by Jose on 10/31/12.
//  Copyright (c) 2012 Jose. All rights reserved.
//

#import "ViewController.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))


@implementation ViewController {
    CMAttitude *referenceAttitude;
    CMAcceleration referenceGravity;
    int maxDC;
    int minDC;
    float sphereAttitudePos;
    float sphereCompassPos;
    float sphereSize;
    float spacing;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self createSphere:1 rings:50 sectors: 100];
    motionManager = [[CMMotionManager alloc] init];
    locationManager = [[CLLocationManager alloc] init];
    
    referenceAttitude = nil;
    
    [self toggleUpdates];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    [self loadTextures];
    maxDC = 494;
    minDC = 448;
    
    if (self.view.frame.size.height == 480) {
        sphereAttitudePos = 1.3;
        sphereCompassPos = 1.0;

    } else {
        sphereAttitudePos = 0.93;
        sphereCompassPos = 1.05;
    }
    
    
    sphereSize = 1.0;
    spacing = .1;
    
    [self handleResetDC: nil];
    
}

-(void) toggleUpdates
{
    CMDeviceMotion *deviceMotion = motionManager.deviceMotion;
    CMAttitude *attitude = deviceMotion.attitude;
    referenceAttitude = attitude;
    [motionManager startDeviceMotionUpdates];
    [motionManager startAccelerometerUpdates];
    [motionManager startGyroUpdates];
    [motionManager startMagnetometerUpdates];
    
    [locationManager startUpdatingHeading];
    
    
}

- (IBAction)handleResetDC: (UILongPressGestureRecognizer *)recognizer {
    CGPoint c = self.dc.center;
    c.y = (maxDC + minDC)/2.0;
    self.dc.center = c;
}

- (IBAction)handlePan: (UIPanGestureRecognizer *)recognizer {
    
    CGPoint t = [recognizer translationInView: self.view];
    CGPoint c = self.dc.center;
    
    if (t.x < 0) {
        c.y = c.y + 1;
        if (c.y > maxDC) c.y = maxDC;
        self.dc.center = c;
    } else {
        c.y = c.y - 1;
        if (c.y < minDC) c.y =minDC;
        self.dc.center = c;
    }
    if(recognizer.state == UIGestureRecognizerStateEnded)
    {
        NSLog(@"save %f ", c.y);

        NSUserDefaults *defaultsData = [NSUserDefaults standardUserDefaults];
        [defaultsData setFloat: c.y forKey:@"dcy"];
        [defaultsData synchronize];

    }
}

-(IBAction)handleCalibrate:(UILongPressGestureRecognizer *)recognizer {
    
    // Load cursor position from defaults
    NSUserDefaults *defaultsData = [NSUserDefaults standardUserDefaults];
    CGPoint c = self.dc.center;
    c.y = [[defaultsData  valueForKey: @"dcy"] floatValue];
    self.dc.center = c;
    
    
    // set current device position as reference
    CMDeviceMotion *deviceMotion = motionManager.deviceMotion;

    // get reference position
    referenceAttitude = motionManager.deviceMotion.attitude;
    referenceGravity = deviceMotion.gravity;
}

-(double) atan: (double)x y: (double) y {
    double a = atan(y/x);
    
    if ((x<0)&(y>=0))
        a = M_PI + a;
    else if ((x<0)&(y<0))
        a = M_PI + a;
   
    return a;
}

- (void)getEuler: (CMQuaternion) q vector:(GLKVector3 *) v {
    //q = cos(a/2) + i ( x * sin(a/2)) + j (y * sin(a/2)) + k ( z * sin(a/2))
    
    v->x = atan2(2*(q.w*q.x + q.y*q.z), 1-2*(q.x*q.x+q.y*q.y));
    v->y = asin(2*(q.w*q.y - q.z*q.x));
    v->z = atan2(2*(q.w*q.z + q.y*q.x), 1-2*(q.z*q.z+q.y*q.y));
}

-(void) getDeviceGLRotationMatrix
{
    CMDeviceMotion *deviceMotion = motionManager.deviceMotion;
    CMAttitude *attitude = deviceMotion.attitude;
    CMAcceleration g = deviceMotion.gravity;
    
    if (referenceAttitude == nil)
        [self handleCalibrate: nil];

    // get pitch and roll from quaternion to avoid
    // gimbal lock
    GLKVector3 now;
    GLKVector3 cal;
    [self getEuler:attitude.quaternion vector:&now];
    [self getEuler:referenceAttitude.quaternion vector:&cal];
    
    double pitch = now.x-cal.x;
    double roll  = now.y-cal.y;
    
    rotMatrix = GLKMatrix4Multiply(GLKMatrix4MakeXRotation(pitch), GLKMatrix4MakeZRotation(roll)) ;
    
    //NSLog(@"grav %6.4f %6.4f %6.4f", g.x, g.y, g.z);
    //NSLog(@"att.q %6.4f, %6.4f, %6.4f, %6.4f", q.w, q.x, q.y, q.z);
    //NSLog(@"quat %6.4f, %6.4f, %6.4f, %6.4f", quat.w, quat.x, quat.y, quat.z);

    // get heading and calculate device tilt.
    double tz =  M_PI_2 + [self atan:g.x y:g.y];
    double heading = locationManager.heading.magneticHeading * M_PI / 180.0;

    gravMatrix = GLKMatrix4Identity;
    gravMatrix = GLKMatrix4Rotate(gravMatrix, tz, 0,0,1);
    gravMatrix = GLKMatrix4Rotate(gravMatrix, heading, 0,1,0);
 
    //NSLog(@"heading %f", locationManager.heading.magneticHeading);
}

- (void) createSphere: (float) radius rings:(unsigned int) rings sectors: (unsigned int) sectors
{
    float const R = 1./(float)(rings-1);
    float const S = 1./(float)(sectors-1);
    int r, s;
    
    _stride = 3 + 3 + 2;
    _vertexData = (GLfloat*)malloc(rings * sectors * sizeof(GLfloat) * _stride);
    _nvertex = rings * sectors;

    
    GLfloat* item = _vertexData;
    
    
    for(r = 0; r < rings; r++) for(s = 0; s < sectors; s++) {
        float const y = sin( -M_PI_2 + M_PI * r * R );
        float const x = sin(2*M_PI * s * S) * sin( M_PI * r * R );
        float const z = -cos(2*M_PI * s * S) * sin( M_PI * r * R );
        
        // vertex
        *item++ = x * radius;
        *item++ = y * radius;
        *item++ = z * radius;
        
        //normals
        *item++ = x;
        *item++ = y;
        *item++ = z;


        *item++ = s*S;
        *item++ = r*R;
        
        //NSLog(@"att %f %f %f %f %f", x* radius,y* radius,z* radius, s*S, r*R);

    }
    
  
    _indexData = (GLushort*)malloc(rings * sectors * 6*sizeof(GLushort));
    _nindices = rings * sectors * 6;

    
    GLushort *i = _indexData;
    for(r = 0; r < rings-1; r++)
        for(s = 0; s < sectors-1; s++) {
            
            *i++ = r * sectors + s;
            *i++ = r * sectors + (s+1);
            *i++ = (r+1) * sectors + (s+1);

            *i++ = r * sectors + s;
            *i++ = (r+1) * sectors + s;
            *i++ = (r+1) * sectors + (s+1);
        }
    
}



GLuint loadTexture(const char *inFileName, int inWidth, int inHeight) {
	glEnable(GL_TEXTURE_2D);
	//glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
	GLuint texture;
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	
	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_MIRRORED_REPEAT_OES);
	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_MIRRORED_REPEAT_OES);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	//glBlendFunc(GL_ONE, GL_SRC_COLOR);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    
	NSString *fname=[NSString stringWithUTF8String:inFileName];
	NSString *extension = [fname pathExtension];
	NSString *baseFilenameWithExtension = [fname lastPathComponent];
	NSString *baseFilename = [baseFilenameWithExtension substringToIndex:[baseFilenameWithExtension length] - [extension length] - 1];
	
	NSString *path = [[NSBundle mainBundle] pathForResource:baseFilename ofType:extension];
	NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
	
	// Assumes pvr4 is RGB not RGBA, which is how texturetool generates them
//	if ([extension isEqualToString:@"pvr4"])
//		glCompressedTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG, inWidth, inHeight, 0, (inWidth * //inHeight) / 2, [texData bytes]);
//	else if ([extension isEqualToString:@"pvr2"])
//		glCompressedTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG, inWidth, inHeight, 0, (inWidth * inHeight) / 2, [texData bytes]);
//	else
	{
		UIImage *image = [[UIImage alloc] initWithData:texData];
		if (image == nil)
			return 0;
		
		GLuint width = CGImageGetWidth(image.CGImage);
		GLuint height = CGImageGetHeight(image.CGImage);
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		void *imageData = malloc( height * width * 4 );
		CGContextRef context = CGBitmapContextCreate( imageData, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
		CGColorSpaceRelease( colorSpace );
		CGContextClearRect( context, CGRectMake( 0, 0, width, height ) );
		CGContextDrawImage( context, CGRectMake( 0, 0, width, height ), image.CGImage );
		
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
        //        glGenerateMipmapEXT(GL_TEXTURE_2D);  //Generate mipmaps now!!!
		//GLuint errorcode = glGetError();
		CGContextRelease(context);
		
		free(imageData);
		//[image release];
	}
	return texture;
}

- (void)loadTextures
{
    _attitureTextureId = loadTexture("attitude.png", -1, -1);
    _compassTextureId = loadTexture("compass.png", -1, -1);
}



- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
    
    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    // Set vertex buffer
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, _nvertex*sizeof(GLfloat)*_stride, _vertexData, GL_STATIC_DRAW);
    
    // Set index buffer
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _nindices*sizeof(GLushort), _indexData, GL_STATIC_DRAW);
    
    int stride = sizeof(GLfloat)*_stride;
    
    // set Arrays
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, stride, BUFFER_OFFSET(0));
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, stride, BUFFER_OFFSET(12));

    // color
    //glEnableVertexAttribArray(GLKVertexAttribColor);
    //glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, stride, BUFFER_OFFSET(24));

    // texture
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, stride, BUFFER_OFFSET(24));
    
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    float height = sphereSize*(1+spacing)*2;
    float width = height * aspect;
        
    //GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-width, width, -height, height, 0, 10);
    
    [self getDeviceGLRotationMatrix];
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation( 0.0f, -sphereSize*(sphereAttitudePos+spacing), 0.0f);
    GLKMatrix4 baseModelViewMatrix2 = GLKMatrix4MakeTranslation( 0.0f, sphereSize*(sphereCompassPos+spacing), 0.0f);
    
    
 #if TARGET_IPHONE_SIMULATOR
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 0.0f, 1.0f);
    baseModelViewMatrix2 = GLKMatrix4Rotate(baseModelViewMatrix2, _rotation, 0.0f, 1.0f, 0.0f);
#else
    
    baseModelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, rotMatrix);
    baseModelViewMatrix2 = GLKMatrix4Multiply(baseModelViewMatrix2, gravMatrix);
#endif
    
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -5.0f);
    
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(GLKMatrix4Multiply(modelViewMatrix,baseModelViewMatrix)), NULL);
    _normalMatrix2 = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(GLKMatrix4Multiply(modelViewMatrix, baseModelViewMatrix2)), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, GLKMatrix4Multiply(modelViewMatrix, baseModelViewMatrix));
    _modelViewProjectionMatrix2 = GLKMatrix4Multiply(projectionMatrix, GLKMatrix4Multiply(modelViewMatrix, baseModelViewMatrix2));
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glEnable(GL_DEPTH_TEST);
    glClearColor(0.3f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _attitureTextureId);
    glUniform1i(_uniformTexture, 0);
    
    
    glUniformMatrix3fv(_uniformNormalMatrix, 1, 0, _normalMatrix.m);
    glUniformMatrix4fv(_uniformModelviewProjectionMatrix, 1, 0, _modelViewProjectionMatrix.m);
    glDrawElements(GL_TRIANGLES, _nindices, GL_UNSIGNED_SHORT, 0);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _compassTextureId);
    glUniform1i(_uniformTexture, 0);

    
    glUniformMatrix3fv(_uniformNormalMatrix, 1, 0, _normalMatrix2.m);
    glUniformMatrix4fv(_uniformModelviewProjectionMatrix, 1, 0, _modelViewProjectionMatrix2.m);
    glDrawElements(GL_TRIANGLES, _nindices, GL_UNSIGNED_SHORT, 0);
   
    
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texcoord");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    _uniformModelviewProjectionMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    _uniformNormalMatrix = glGetUniformLocation(_program, "normalMatrix");
    _uniformTexture = glGetUniformLocation(_program, "texture");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}


@end
