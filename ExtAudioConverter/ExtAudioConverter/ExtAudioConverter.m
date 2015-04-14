//
//  ExtAudioConverter.m
//  ExtAudioConverter
//
//  Created by 李 行 on 15/4/9.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import "ExtAudioConverter.h"

typedef struct ExtAudioConverterSettings{
    AudioStreamBasicDescription inputPCMFormat;
    AudioStreamBasicDescription outputFormat;
    
    ExtAudioFileRef             inputFile;
    AudioFileID                 outputFile;
    
    AudioStreamPacketDescription* inputPacketDescriptions;
    SInt64 outputFileStartingPacketCount;
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

void startConvert(ExtAudioConverterSettings* settings){
    //Determine the proper buffer size and calculate number of packets per buffer
    //for CBR and VBR format
    UInt32 sizePerBuffer = 32*1024;//32KB is a good starting point
    UInt32 sizePerPacket = settings->outputFormat.mBytesPerPacket;
    UInt32 packetsPerBuffer;
    
    //For a format that uses variable packet size
    UInt32 size = sizeof(sizePerPacket);
    if (sizePerPacket==0) {
        CheckError(ExtAudioFileGetProperty(settings->inputFile,
                                           kExtAudioFileProperty_FileMaxPacketSize,
                                           &size,
                                           &sizePerPacket),
                   "ExtAudioFileGetProperty kExtAudioFileProperty_FileMaxPacketSize failed");
        if (sizePerBuffer<sizePerPacket) {
            sizePerBuffer = sizePerPacket;
        }
        
        packetsPerBuffer = sizePerBuffer/sizePerPacket;
        settings->inputPacketDescriptions = (AudioStreamPacketDescription*)malloc(packetsPerBuffer*sizeof(AudioStreamPacketDescription));
    }else{//For a format that uses Constant packet size
        packetsPerBuffer = sizePerBuffer/sizePerPacket;
    }
    
    // allocate destination buffer
    UInt8 *outputBuffer = (UInt8 *)malloc(sizeof(UInt8) * sizePerBuffer);
    
    AudioConverterRef audioConverter;
    AudioConverterNew(&settings->inputPCMFormat,
                      &settings->outputFormat,
                      &audioConverter);
    
    settings->outputFileStartingPacketCount = 0;
    while (YES) {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers = 1;
        outputBufferList.mBuffers[0].mNumberChannels = settings->outputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize = sizePerBuffer;
        outputBufferList.mBuffers[0].mData = outputBuffer;
        
        UInt32 framesCount = packetsPerBuffer;
        
        CheckError(ExtAudioFileRead(settings->inputFile,
                                    &framesCount,
                                    &outputBufferList),
                   "ExtAudioFileRead failed");
        
        if (framesCount==0) {
            printf("Done reading from input file\n");
            return;
        }
        
        //Write the converted data to the output file
        CheckError(AudioFileWritePackets(settings->outputFile,
                                         NO,
                                         framesCount,
                                         //settings->inputPacketDescriptions?settings->inputPacketDescriptions:nil,
                                         NULL,
                                         //settings->outputFileStartingPacketCount/settings->outputFormat.mBytesPerPacket,//为什么要除以bytesPerPacket?
                                         settings->outputFileStartingPacketCount,
                                         &framesCount,
                                         outputBufferList.mBuffers[0].mData),
                   "AudioFileWritePackets failed");
        //NSLog(@"packet count:%lld",settings->outputFileStartingPacketCount);
        settings->outputFileStartingPacketCount += framesCount;
    }
}

@implementation ExtAudioConverter

@synthesize inputFile;
@synthesize outputFile;
@synthesize outputSampleRate;
@synthesize outputNumberChannels;
@synthesize outputBitDepth;


-(BOOL)convert{
    ExtAudioConverterSettings settings = {0};
    
    //Check if source file or output file is null
    if (self.inputFile==NULL) {
        NSLog(@"Source file is not set");
        return NO;
    }
    
    if (self.outputFile==NULL) {
        NSLog(@"Output file is no set");
        return NO;
    }
    
    //Create ExtAudioFileRef
    NSURL* sourceURL = [NSURL fileURLWithPath:self.inputFile];
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
    settings.outputFormat.mBitsPerChannel   = self.outputBitDepth;
    settings.outputFormat.mChannelsPerFrame = self.outputNumberChannels;
    settings.outputFormat.mFormatID         = self.outputFormatID;
    
    //only for linear PCM format
    settings.outputFormat.mBytesPerFrame = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
    settings.outputFormat.mBytesPerPacket = settings.outputFormat.mBytesPerFrame;
    settings.outputFormat.mFramesPerPacket = 1;
    settings.outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
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
    settings.inputPCMFormat.mSampleRate = 44100;
    settings.inputPCMFormat.mFormatID = kAudioFormatLinearPCM;
    settings.inputPCMFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    settings.inputPCMFormat.mFramesPerPacket = 1;
    settings.inputPCMFormat.mChannelsPerFrame = 2;
    settings.inputPCMFormat.mBytesPerFrame = 4;
    settings.inputPCMFormat.mBytesPerPacket = 4;
    settings.inputPCMFormat.mBitsPerChannel = 16;
    
    CheckError(ExtAudioFileSetProperty(settings.inputFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       sizeof(settings.inputPCMFormat),
                                       &settings.inputPCMFormat),
               "Setting client data format of input file failed");
    
    printf("Start converting...\n");
    startConvert(&settings);
    
    ExtAudioFileDispose(settings.inputFile);
    //AudioFileClose function is needed, or else for .wav output file the duration will be 0
    AudioFileClose(settings.outputFile);
    return YES;
}

@end
