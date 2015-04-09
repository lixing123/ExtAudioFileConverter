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
    
    //Get input file's format
    
    
    //Set output format
    if (self.outputSampleRate==0) {
        self.outputSampleRate = 44100;
    }
    
    if (self.outputNumberChannels==0) {
        self.outputNumberChannels = 2;
    }
    
    if (self.outputBitDepth==0) {
        self.outputBitDepth = 16;
    }
    
    if (self.outputFormatID==0) {
        self.outputFormatID = kAudioFormatLinearPCM;
    }
    
    if (self.outputFileType==0) {
        self.outputFileType = kAudioFileWAVEType;
    }
    
    settings.outputFormat.mSampleRate       = self.outputSampleRate;
    settings.outputFormat.mBitsPerChannel   = self.outputSampleRate;
    settings.outputFormat.mChannelsPerFrame = self.outputNumberChannels;
    settings.outputFormat.mFormatID         = self.outputFormatID;
    
    //Create output file
    NSURL* outputURL = [NSURL fileURLWithPath:self.outputFile];
    CheckError(AudioFileCreateWithURL((__bridge CFURLRef)outputURL,
                                      self.outputFileType,
                                      &settings.outputFormat,
                                      kAudioFileFlags_EraseFile,
                                      &settings.outputFile),
               "Create output file failed");
    
    //Set input file's client data format
    //Must be PCM, thus as we say, "when you convert data, I want to receive PCM format"
    AudioStreamBasicDescription clientDataFormat;
    clientDataFormat.mSampleRate = 44100;
    clientDataFormat.mFormatID = kAudioFormatLinearPCM;
    clientDataFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    clientDataFormat.mFramesPerPacket = 1;
    clientDataFormat.mChannelsPerFrame = 2;
    clientDataFormat.mBytesPerFrame = 2;
    clientDataFormat.mBytesPerPacket = 2;
    clientDataFormat.mBitsPerChannel = 16;
    
    CheckError(ExtAudioFileSetProperty(settings.inputFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       sizeof(clientDataFormat),
                                       &clientDataFormat),
               "Setting client data format of input file failed");
    
    
    
    return YES;
}

@end
