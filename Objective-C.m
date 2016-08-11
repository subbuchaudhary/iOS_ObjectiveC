//
//  Objective-C.m
//  subbu
//
//  Created by Saibersys on 8/11/16.
//  Copyright © 2016 Saibersys. All rights reserved.
//

#import "Objective-C.h"

@implementation Objective_C

-(void) print {
    NSLog(@"I am %i years old and weighs %i kgs", age, weight);
}
-(void) setAge : (int) a {
    age = a;
}
-(void) setWeight : (int) w {
    weight = w;
}

@end
