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
        //converter.inputFile =  @"/Users/lixing/Desktop/new.m4a";
        //converter.inputFile =  @"/Users/xingli/Desktop/input.mp3";
        //output file extension is for your convenience
        converter.outputFile = @"/Users/lixing/Desktop/output.mp3";
        
        //TODO:some option combinations are not valid.
        //Check them out
        converter.outputSampleRate = 44100;
        converter.outputNumberChannels = 2;
        converter.outputBitDepth = BitDepth_16;
        converter.outputFormatID = kAudioFormatMPEGLayer3;
        converter.outputFileType = kAudioFileMP3Type;
        [converter convert];
    }
    return 0;
}
