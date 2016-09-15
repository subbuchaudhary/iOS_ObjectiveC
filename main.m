//
//  main.m
//  inheritance
//
#import <Foundation/Foundation.h>

@interface Subbu : NSObject {
    int numb;
}
-(void) setNumb: (int) a;

@end

@implementation Subbu

-(void) setNumb:(int)a {
    numb = a;
}

@end

@interface Nivas : Subbu
-(void) print;

@end

@implementation Nivas

-(void) print {
    NSLog(@"%i", numb);
}

@end
int main (int argc, char *argv[]) {
    @autoreleasepool {
        Nivas *Don = [[Nivas alloc] init];
        [Don setNumb:18];
        [Don print];
    }
    return 0;
}