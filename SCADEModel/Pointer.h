//
//  Pointer.h
//  SCADEModel
//
//  Created by Dev Apple on 29/03/13.
//  Copyright (c) 2013 Esterel Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Pointer : NSObject
@property NSUInteger hash;
@property float x;
@property float y;
@property int pointer_id;
@property int button;
@property int state;
@property int modifiers;
@end
