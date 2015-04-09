//
//  ExtAudioConverter.m
//  ExtAudioConverter
//
//  Created by 李 行 on 15/4/9.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import "ExtAudioConverter.h"

typedef struct ExtAudioConverterSettings{
    AudioStreamBasicDescription outputFormat;
    ExtAudioFileRef             inputFile;
    AudioFileID                 outputFile;
}ExtAudioConverterSettings;

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

@implementation ExtAudioConverter

@synthesize sourceFile;
@synthesize outputFile;
@synthesize outputSampleRate;
@synthesize outputNumberChannels;
@synthesize outputBitDepth;

-(BOOL)convert{
    ExtAudioConverterSettings settings = {0};
    
    //Check if source file or output file is null
    if (self.sourceFile==NULL) {
        NSLog(@"Source file is not set");
        return NO;
    }
    
    if (self.outputFile==NULL) {
        NSLog(@"Output file is no set");
        return NO;
    }
    
    //Create ExtAudioFileRef
    NSURL* sourceURL = [NSURL fileURLWithPath:self.sourceFile];
    CheckError(ExtAudioFileOpenURL((__bridge CFURLRef)sourceURL,
                                   &settings.inputFile),
               "ExtAudioFileOpenURL failed");
    
    settings.outputFormat.mSampleRate = self.outputSampleRate?self.outputSampleRate:44100;//Default 44100
    settings.outputFormat.mBitsPerChannel = self.outputSampleRate?self.outputSampleRate/8:2;//Default 2
    settings.outputFormat.mChannelsPerFrame = self.outputNumberChannels?self.outputNumberChannels:2;//Default 2
    
    return YES;
}

@end
