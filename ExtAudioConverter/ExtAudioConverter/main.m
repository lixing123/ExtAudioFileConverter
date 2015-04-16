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
        converter.inputFile =  @"/Users/lixing/Desktop/playAndRecord.caf";
        converter.outputFile = @"/Users/lixing/Desktop/output.wav";
        
        //TODO:if the output sample rate is not 44100, voice duration will be wrong
        converter.outputSampleRate = 8000;
        converter.outputNumberChannels = 1;
        converter.outputBitDepth = BitDepth_24;
        converter.outputFormatID = kAudioFormatAppleLossless;
        converter.outputFileType = kAudioFileCAFType;
        [converter convert];
    }
    return 0;
}
