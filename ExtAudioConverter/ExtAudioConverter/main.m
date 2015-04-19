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
        converter.inputFile =  @"/Users/xingli/Desktop/input.mp3";
        //output file extension is for your convenience
        converter.outputFile = @"/Users/xingli/Desktop/output.wav";
        
        //TODO:some option combinations are not valid.
        //Check them out
        converter.outputSampleRate = 44100;
        converter.outputNumberChannels = 2;
        converter.outputBitDepth = BitDepth_16;
        converter.outputFormatID = kAudioFormatLinearPCM;
        converter.outputFileType = kAudioFileCAFType;
        [converter convert];
    }
    return 0;
}
