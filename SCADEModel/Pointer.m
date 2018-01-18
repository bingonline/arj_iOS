//
//  Pointer.m
//  SCADEModel
//
//  Created by Dev Apple on 29/03/13.
//  Copyright (c) 2013 Esterel Technologies. All rights reserved.
//

#import "Pointer.h"


@interface Pointer(){
    NSUInteger hash;
    float x;
    float y;
    int pointer_id;
    int button;
    int state;
    int modifiers;
}

@end


@implementation Pointer
@synthesize hash = _hash;
@synthesize x =_x;
@synthesize y =_y;
@synthesize pointer_id = _pointer_id;
@synthesize button = _button;
@synthesize state = _state;
@synthesize modifiers = _modifiers;

@end
