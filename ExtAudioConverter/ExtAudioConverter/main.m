//
//  main.m
//  ExtAudioConverter
//
//  Created by 李 行 on 15/4/9.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ExtAudioConverter.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ExtAudioConverter* converter = [[ExtAudioConverter alloc] init];
        converter.inputFile = @"/Users/lixing/Desktop/playAndRecord.caf";
        converter.outputFile = @"/Users/lixing/Desktop/output.wav";
        [converter convert];
    }
    return 0;
}
