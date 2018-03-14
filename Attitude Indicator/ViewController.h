//
//  ViewController.h
//  Attitude Indicator
//
//  Created by Jose on 10/31/12.
//  Copyright (c) 2012 Jose. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h> 


@interface ViewController : GLKViewController {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix4 _modelViewProjectionMatrix2;
    GLKMatrix3 _normalMatrix;
    GLKMatrix3 _normalMatrix2;
    
    float _rotation;
    
    GLfloat* _vertexData;
    GLushort* _indexData;
    int _nindices;
    int _nvertex;
    int _stride;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    GLuint _indexArray;
    GLuint _indexBuffer;
    
    GLint _uniformModelviewProjectionMatrix;
    GLint _uniformNormalMatrix;
    GLint _uniformTexture;
    
    GLuint _attitureTextureId;
    GLuint _compassTextureId;
    
    CMMotionManager *motionManager;
    CLLocationManager *locationManager;

    NSTimer *timer;
    
    GLKMatrix4 rotMatrix;
    GLKMatrix4 gravMatrix;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;
@property (strong, nonatomic) IBOutlet UIImageView *dc;


@end


