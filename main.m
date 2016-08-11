//
//  main.m
//  subbu
//
//  Created by Saibersys on 8/11/16.
//  Copyright © 2016 Saibersys. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Objective-C.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Objective_C *subbu = [[Objective_C alloc] init];
        [subbu setAge:22];
        [subbu setWeight:69];
        [subbu print];
    }
    return 0;
}
