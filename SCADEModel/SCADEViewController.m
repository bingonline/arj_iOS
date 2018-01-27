//
//  SCADEViewController.m
//  SCADEModel
//
//  Created by Dev Apple on 19/03/13.
//  Copyright (c) 2013 Esterel Technologies. All rights reserved.
//

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#import <OpenGLES/ES3/glext.h>
#endif
#import <QuartzCore/QuartzCore.h>
#import "SCADEViewController.h"
#import "Pointer.h"
#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>

#define IOS_DEV_ENV
#define ES2_DEV_ENV
#import "oglx.h"
#include "target_configuration.h"
#include "sdy_events.h"
#include "aol_color_table.h"
#include "aol_line_width_table.h"
#include "aol_line_stipple_table.h"
#include "aol_texture_table.h"
#include "aol_font_table.h"
#include "Tcp.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))
extern void Reset();
extern void Step();
extern void BHVR_Pointer(const sdy_pointer_event_t *evt);
extern void BHVR_Gyro(const sdy_gyro_event_t *evt);
extern void BHVR_Accelerometer(const sdy_accelerometer_event_t *evt);
extern void BHVR_Magnetometer(const sdy_magnetometer_event_t *evt);


#define POINTER_UNKNOWN 0
#define POINTER_PRESSED 1
#define POINTER_RELEASED 2
#define POINTER_NOT_RELEASED 3

@interface SCADEViewController () {
    GLuint _program;
    double lastTime;
    CGFloat zoom;
    int displayWidth, displayHeight;
    CGFloat currentHeight;
    GLuint _colorRenderBuffer;
    float screenRatio;
    Pointer* pointers[MAX_POINTERS];
    sgl_type_statemachine* glob_s_context;
}

@property (strong,nonatomic)CMMotionManager *motionManger;
@property (strong, nonatomic) EAGLContext *context;
@property (strong,nonatomic) CLLocationManager *locationManger;
- (void)computeSizes;
- (void)initOGLX;
- (void)setupGL;
- (void)tearDownGL;
- (Pointer*)pointerWithHashNumber:(NSUInteger)hash;
@end



typedef struct
{
    double latitude;
    double longitude;
    float altitude;
    float pitch;
    float roll;
    float magHeading;
    float heading;
    float course;
    float speed;
    
}SensorInfo;


SensorInfo the_sensor_info;

@implementation SCADEViewController


- (CMMotionManager *)cmMotionManager
{
    CMMotionManager *cmMotionManager = nil;
    
    id appDelegate = [UIApplication sharedApplication].delegate;
    
    if ([appDelegate respondsToSelector:@selector(cmMotionManager)]) {
        cmMotionManager = [appDelegate cmMotionManager];
    }
    
    return cmMotionManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    for(int i=0; i<MAX_POINTERS; i++){
        pointers[i] = [[Pointer alloc]init];
        [self initPointerWithId:i];
    }
    glob_s_context = malloc(sizeof(sgl_type_statemachine));
    memset(glob_s_context, 0, sizeof(sgl_type_statemachine));

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    
    view.multipleTouchEnabled = YES;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableStencilFormat = GLKViewDrawableStencilFormat8;
#ifdef NO_MULTISAMPLING
	view.drawableMultisample = GLKViewDrawableMultisampleNone;
#else
	view.drawableMultisample = GLKViewDrawableMultisample4X;
#endif
    
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)view.layer];
    lastTime = 0.0;
    [self setupGL];
    
  
    self.motionManger=[[CMMotionManager alloc]init];
    if(self.motionManger.deviceMotionAvailable)
    {
        [self.motionManger startDeviceMotionUpdates];
    }else
    {
        NSLog(@"deviceMotion not available");
    }
    self.locationManger=[[CLLocationManager alloc]init];
    self.locationManger.delegate=self;
    self.locationManger.desiredAccuracy=kCLLocationAccuracyBest;
    
    [self.locationManger startUpdatingLocation];
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *currLocation=[locations firstObject];
    the_sensor_info.latitude=currLocation.coordinate.latitude;
    the_sensor_info.longitude=currLocation.coordinate.longitude;
    the_sensor_info.altitude=currLocation.altitude;
    the_sensor_info.speed=currLocation.speed;
    the_sensor_info.course=currLocation.course;
    NSLog(@"%3.5f,%3.5f,%3.5f,%3.5f,%3.5f",the_sensor_info.latitude,the_sensor_info.longitude,the_sensor_info.altitude,the_sensor_info.speed,the_sensor_info.course);
    
}
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    if(newHeading.headingAccuracy>0)
    {
        the_sensor_info.heading=newHeading.trueHeading;
        the_sensor_info.magHeading=newHeading.magneticHeading;
    }
}


- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    free(glob_s_context);
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
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

- (void)viewDidAppear:(BOOL)animated
{
    
    [super viewDidAppear:animated];
    
    [self.cmMotionManager startGyroUpdates];
    [self.cmMotionManager startAccelerometerUpdates];
    [self.cmMotionManager startMagnetometerUpdates];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    
    [super viewDidDisappear:animated];
    
    [self.cmMotionManager stopGyroUpdates];
    [self.cmMotionManager stopAccelerometerUpdates];
    [self.cmMotionManager stopMagnetometerUpdates];
    
}


- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    zoom = 1.0f;
    [self initOGLX];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

- (void)update
{
}

- (void) initPointerWithId: (int) pointerId
{
    pointers[pointerId].hash = 0;
    pointers[pointerId].x = -1.0f;
    pointers[pointerId].y = -1.0f;
    pointers[pointerId].pointer_id = pointerId;
    pointers[pointerId].button = 0;
    pointers[pointerId].state = POINTER_UNKNOWN;
    pointers[pointerId].modifiers = 0;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    if(displayWidth == 0){
        [self computeSizes];
    }
    
    double currentTime = CACurrentMediaTime();
    double dt = currentTime - lastTime;
    double period = getPeriodicity() / 1000.0;
    if (dt < period){
        [NSThread sleepForTimeInterval:(period-dt)];
    }
    lastTime = CACurrentMediaTime();
    
    glClearColor(getBackgroundRed(), getBackgroundGreen(), getBackgroundBlue(), 0.0f);
    glClearStencil(0x0);
    glClear(GL_COLOR_BUFFER_BIT|GL_STENCIL_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
       
    sglViewport(0, 0, displayWidth, displayHeight);
    
    // update gyro data
    CMGyroData* lGyroData = [self.cmMotionManager gyroData];
    sdy_gyro_event_t gyroEvent;
    gyroEvent.id = 0;
    gyroEvent.x = lGyroData.rotationRate.x;
    gyroEvent.y = lGyroData.rotationRate.y;
    gyroEvent.z = lGyroData.rotationRate.z;
    BHVR_Gyro(&gyroEvent);
    
    // update accelerometer data
    CMAccelerometerData* lAccelerometerData = [self.cmMotionManager accelerometerData];
    sdy_accelerometer_event_t accelerometerEvent;
    accelerometerEvent.id = 0;
    accelerometerEvent.x = lAccelerometerData.acceleration.x;
    accelerometerEvent.y = lAccelerometerData.acceleration.y;
    accelerometerEvent.z = lAccelerometerData.acceleration.z;
    BHVR_Accelerometer(&accelerometerEvent);
    
    // update magnetometer data
    CMMagnetometerData* lMagnetometerData = [self.cmMotionManager magnetometerData];
    sdy_magnetometer_event_t magnetometerEvent;
    magnetometerEvent.id = 0;
    magnetometerEvent.x = lMagnetometerData.magneticField.x;
    magnetometerEvent.y = lMagnetometerData.magneticField.y;
    magnetometerEvent.z = lMagnetometerData.magneticField.z;
    BHVR_Magnetometer(&magnetometerEvent);
    
    // update pointers
    for(int i=0; i< MAX_POINTERS; i++){
        Pointer *pointer = pointers[i];
        sdy_pointer_event_t event;
		event.id = pointer.pointer_id;
		event.position[0] = pointer.x;
		event.position[1] = pointer.y;
		event.button = pointer.button;
		event.pressed = (pointer.state == POINTER_PRESSED);
		event.released = (pointer.state == POINTER_RELEASED);
		BHVR_Pointer(&event);

        if(pointer.state == POINTER_RELEASED){
            [self initPointerWithId:i];
        } else if(pointer.state == POINTER_PRESSED){
            pointers[i].state = POINTER_NOT_RELEASED;
        }
    }
    //TcpRecv();
    CMDeviceMotion *deviceMotion=self.motionManger.deviceMotion;
    //if(self.motionManger.deviceMotionAvailable)
    //{
        //NSLog(@"%+.2f\n",deviceMotion.attitude.yaw);
        //deviceMotion
    //}
    
    //NSLog(@"%.8f",)
   // NSLog(@"%3.5f,%3.5f,%3.5f",the_sensor_info.latitude,the_sensor_info.longitude,the_sensor_info.altitude);
    
    
    
    Step();
    glFlush();
}



- (void)reset
{
    sglReset();
}

- (void)terminate
{
	sglTerminate();
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self computeSizes];
}

- (void)initOGLX
{
    /* Initialize OGLX */
	static SGLbyte glob_tub_texture_buffer[4 * SGL_TEXTURE_MAX_WIDTH * SGL_TEXTURE_MAX_HEIGHT];
static sgl_texture_attrib glob_texture_attrib[aol_texture_table_size];
	static sgl_parameters lParameters;

	lParameters.ul_screen_width = getW();
	lParameters.ul_screen_height = getH();
	lParameters.pb_texture_buffer = glob_tub_texture_buffer;
	lParameters.ul_texture_max_width = SGL_TEXTURE_MAX_WIDTH;
	lParameters.ul_texture_max_height = SGL_TEXTURE_MAX_HEIGHT;
   lParameters.p_texture_attrib = glob_texture_attrib;
  lParameters.ul_number_of_textures = aol_texture_table_size;
    if (sglInit(glob_s_context, &lParameters)){
        
        /* Load the color table */
        sglColorPointerf(getColorTable(), getColorTableSize());
        
        /* Set the OGLX line mode (SMOOTH) and load the corresponding line width table */
        sglSetRenderMode(SGL_SMOOTH_LINES);
        sglLineWidthPointerf((const sgl_line_width *) getLineWidthTable(), (SGLulong) getLineWidthTableSize());
        
        /* Load the line stipple table */
        sglLineStipplePointer((const sgl_linestipple *) (getLineStippleTable()), aol_line_stipple_table_size);
        
        /* Load the fonts table */
        sgluLoadFonts(getFontTable());
        
        /* Load the textures table */
        aol_texture_table();
        
        sglViewport(0, 0, getW(), getH());
        sglOrtho(0, (float) (getW() * getRatioX()),
                 0, (float) (getH() * getRatioY()));
        
        // Create a packed depth stencil buffer.
        GLuint depthStencil;
        glGenRenderbuffers(1, &depthStencil);
        glBindRenderbuffer(GL_RENDERBUFFER, depthStencil);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, getW(), getH());
#else
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, getW(), getH());
#endif
        
        // Create the framebuffer object.
        GLuint framebuffer;
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthStencil);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthStencil);
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
        
        glDisable(GL_DEPTH_TEST);
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
        if(status != GL_FRAMEBUFFER_COMPLETE)
#else
        GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) ;
        if(status != GL_FRAMEBUFFER_COMPLETE_OES)
#endif
        {
            /*
             #define GL_FRAMEBUFFER_COMPLETE_OES                             0x8CD5
             #define GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_OES                0x8CD6
             #define GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT_OES        0x8CD7
             #define GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_OES                0x8CD9
             #define GL_FRAMEBUFFER_INCOMPLETE_FORMATS_OES                   0x8CDA
             #define GL_FRAMEBUFFER_UNSUPPORTED_OES                          0x8CDD
             */
            NSLog(@"failed to make complete framebuffer object %x", status);
        } else {
            NSLog(@"GL_FRAMEBUFFER_COMPLETE_OES");
        }
        
        Reset();
    }
}

-(void)logError
{
    GLenum error = glGetError();
    if(error != GL_NO_ERROR) {
        
        if(error == GL_INVALID_ENUM)NSLog(@"Error: GL_INVALID_ENUM");
        
        if(error == GL_INVALID_VALUE)NSLog(@"Error: GL_INVALID_VALUE");
        
        if(error == GL_INVALID_OPERATION)NSLog(@"Error: GL_INVALID_OPERATION");
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#else
        if(error == GL_STACK_OVERFLOW)NSLog(@"Error: GL_STACK_OVERFLOW");
        
        if(error == GL_STACK_UNDERFLOW)NSLog(@"Error: GL_STACK_UNDERFLOW");
#endif
        if(error == GL_OUT_OF_MEMORY)NSLog(@"Error: GL_OUT_OF_MEMORY");
    }
}

- (void)computeSizes
{
    GLKView *view = (GLKView *)self.view;
    CGFloat drawableWidth = view.drawableWidth;
    CGFloat drawableHeight = view.drawableHeight;
    CGFloat zoomX, zoomY;
    CGFloat frameWidth = view.frame.size.width;
    CGFloat frameHeight = view.frame.size.height;
    
    screenRatio = MAX(drawableHeight, drawableWidth) / MAX(frameHeight, frameWidth);
    
    zoomX = getW()/drawableWidth;
    zoomY = getH()/drawableHeight;
    
    if (zoomX>zoomY){
        zoom = zoomX;
        displayWidth = drawableWidth;
        displayHeight = (int)(getH()/zoomX);
    } else {
        zoom = zoomY;
        displayWidth = (int)(getW()/zoomY);
        displayHeight = drawableHeight;
    }

    /* iOS7 or before */
    /* int deviceOrientation = [[UIDevice currentDevice] orientation];
     currentHeight = ( deviceOrientation == UIDeviceOrientationLandscapeLeft  ||
     deviceOrientation == UIDeviceOrientationLandscapeRight || 
     deviceOrientation == UIDeviceOrientationUnknown )?view.frame.size.width:view.frame.size.height; */
    
    /* iOS8 or after */                  
    currentHeight = view.frame.size.height;
}

- (Pointer*)pointerWithHashNumber:(NSUInteger)hash
{
    for(int i=0; i<MAX_POINTERS;i++){
        Pointer *pointer = pointers[i];
        if(pointer && pointer.hash == hash) return pointer;
    }
    return nil;
}

-(int)freeIndex
{
    for ( uint idx = 0; idx<MAX_POINTERS; idx++){
        if(pointers[idx].state == POINTER_UNKNOWN)return idx;
    }
    return -1;
}

- (CGPoint)getPoint:(UITouch*)touch{
    CGPoint point;
    CGPoint touchPoint = [touch locationInView:self.view];
    point.x = touchPoint.x*screenRatio*zoom;
    point.y = ((currentHeight-touchPoint.y)*screenRatio)*zoom;
    return point;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for ( uint idx = 0; idx<[touches count]; idx++) {
        UITouch *touch = [[touches allObjects] objectAtIndex:idx];
        CGPoint point = [self getPoint: touch];
        
        int idx = [self freeIndex];
        if(idx!=-1){
            pointers[idx].x = point.x;
            pointers[idx].y = point.y;
            pointers[idx].state = POINTER_PRESSED;
            pointers[idx].modifiers = 0;
            pointers[idx].pointer_id = idx;
            pointers[idx].hash = [touch hash];
         }
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for ( uint idx = 0; idx<[touches count]; idx++) {
        UITouch *touch = [[touches allObjects] objectAtIndex:idx];
        CGPoint point = [self getPoint: touch];
        
        NSUInteger hashNumber = [touch hash];
        Pointer *pointer = [self pointerWithHashNumber:hashNumber];
        if(pointer){
            pointer.x = point.x;
            pointer.y = point.y;
            pointer.state = POINTER_RELEASED;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    for ( uint idx = 0; idx<[touches count]; idx++) {
        UITouch *touch = [[touches allObjects] objectAtIndex:idx];
        CGPoint point = [self getPoint: touch];
        
        NSUInteger hashNumber = [touch hash];
        Pointer *pointer = [self pointerWithHashNumber:hashNumber];
        if(pointer){
            pointer.x = point.x;
            pointer.y = point.y;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    for ( uint idx = 0; idx<[touches count]; idx++) {
        UITouch *touch = [[touches allObjects] objectAtIndex:idx];
        
        NSUInteger hashNumber = [touch hash];
        Pointer *pointer = [self pointerWithHashNumber:hashNumber];
        for(int i=0; i<MAX_POINTERS;i++){
            if(pointers[i] == pointer){
                [self initPointerWithId:i];
            }
        }
    }
}


/******************************************************************************
 *                           Model configuration methods
 *****************************************************************************/

/*+ FUNCTIONS DESCRIPTION ----------------------------------------------
 NAME:           getPeriodicity / getW / getH / getRatioX / getRatioY / getSpecName
 DESCRIPTION:    Return respectively:
 - the periodicity (in ms)
 - the width (in user units) of layers
 - the height (in user units) of layers
 - the X ratio of layers
 - the Y ratio of layers
 - the specification name as generated in the target_configuration.c file
 ---------------------------------------------------------------------+*/
int getPeriodicity()
{
    return target_periodicity;
}

int getW()
{
    return target_screen_width;
}

int getH()
{
    return target_screen_height;
}

float getRatioX()
{
    return (float)ratio_x;
}

float getRatioY()
{
    return (float)ratio_y;
}

const char *getSpecName()
{
    return specification_name;
}


/*+ FUNCTIONS DESCRIPTION ----------------------------------------------
 NAME:           getColorTable / getLineWidthTable / getLineStippleTable / getFontTable
 DESCRIPTION:    Return respectively:
 - the color table
 - the line width table
 - the line stipple table
 - the font table as generated from resource tables
 ---------------------------------------------------------------------+*/

void *getColorTable()
{
    return (void *) (&aol_color_table);
}


int getColorTableSize()
{
    return aol_color_table_size;
}

void *getLineWidthTable()
{
    return (void *) (&aol_line_width_table);
}

int getLineWidthTableSize()
{
    return aol_line_width_table_size;
}

void *getLineStippleTable()
{
    return (void *) (&aol_line_stipple_table);
}

float getBackgroundRed(){
	return (float)(aol_color_table[aol_color_table_background_index].f_red);
}

float getBackgroundGreen(){
	return (float)(aol_color_table[aol_color_table_background_index].f_green);
}

float getBackgroundBlue(){
	return (float)(aol_color_table[aol_color_table_background_index].f_blue);
}

extern void *getFontTable()
{
    return (void *) (&aol_font_table);
}

@end
