//
//  ExtAudioConverter.m
//  ExtAudioConverter
//
//  Created by 李 行 on 15/4/9.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import "ExtAudioConverter.h"

typedef struct ExtAudioConverterSettings{
    AudioStreamBasicDescription   inputPCMFormat;
    AudioStreamBasicDescription   outputFormat;
    
    ExtAudioFileRef               inputFile;
    //TODO:change AudioFileID to ExtAudioFileRef
    AudioFileID                   outputFile;
    
    AudioStreamPacketDescription* inputPacketDescriptions;
    SInt64                        outputFileStartingPacketCount;
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
    while (1) {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers              = 1;
        outputBufferList.mBuffers[0].mNumberChannels = settings->outputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize   = sizePerBuffer;
        outputBufferList.mBuffers[0].mData           = outputBuffer;
        
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
                                         NULL,
                                         settings->outputFileStartingPacketCount/settings->outputFormat.mBytesPerPacket,//why divided by sbytesPerPacket?
                                         &framesCount,
                                         outputBufferList.mBuffers[0].mData),
                   "AudioFileWritePackets failed");
        NSLog(@"packet count:%lld",settings->outputFileStartingPacketCount);
        settings->outputFileStartingPacketCount += framesCount*settings->outputFormat.mBytesPerPacket;
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
    
    if (self.outputFormatID==kAudioFormatLinearPCM) {
        settings.outputFormat.mBytesPerFrame   = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
        settings.outputFormat.mBytesPerPacket  = settings.outputFormat.mBytesPerFrame;
        settings.outputFormat.mFramesPerPacket = 1;
        settings.outputFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    }else{
        //Set compressed format
        UInt32 size = sizeof(settings.outputFormat);
        CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                          0,
                                          NULL,
                                          &size,
                                          &settings.outputFormat),
                   "AudioFormatGetProperty kAudioFormatProperty_FormatInfo failed");
    }
    NSLog(@"output format:%@",[self descriptionForAudioFormat:settings.outputFormat]);
    
    /*
    switch (self.outputFormatID) {
        case kAudioFormatLinearPCM:{
            settings.outputFormat.mBytesPerFrame   = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
            settings.outputFormat.mBytesPerPacket  = settings.outputFormat.mBytesPerFrame;
            settings.outputFormat.mFramesPerPacket = 1;
            settings.outputFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            break;
        }
        case kAudioFormatAppleIMA4:{
            settings.outputFormat.mBytesPerFrame   = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
            settings.outputFormat.mBytesPerPacket  = settings.outputFormat.mBytesPerFrame;
            settings.outputFormat.mFramesPerPacket = 1;
            settings.outputFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            break;
        }
        default:
            break;
    }*/
    
    //Create output file
    //if output file path is invalid, this may return an error with 'wht?'
    NSURL* outputURL = [NSURL fileURLWithPath:self.outputFile];
    CheckError(AudioFileCreateWithURL((__bridge CFURLRef)outputURL,
                                      self.outputFileType,
                                      &settings.outputFormat,
                                      kAudioFileFlags_EraseFile,
                                      &settings.outputFile),
               "Create output file failed");
    
    /*
     //Extended version of output file creation
    CheckError(ExtAudioFileCreateWithURL((__bridge CFURLRef)outputURL,
                                         self.outputFileType,
                                         &settings.outputFormat,
                                         NULL,
                                         kAudioFileFlags_EraseFile,
                                         &settings.outputFile),
               "Create output file failed");
     */
    
    //Set input file's client data format
    //Must be PCM, thus as we say, "when you convert data, I want to receive PCM format"
    if (settings.outputFormat.mFormatID==kAudioFormatLinearPCM) {
        settings.inputPCMFormat = settings.outputFormat;
    }else{
        settings.inputPCMFormat.mFormatID = kAudioFormatLinearPCM;
        settings.inputPCMFormat.mSampleRate = settings.outputFormat.mSampleRate;
        //TODO:set format flags for both OS X and iOS, for all versions
        settings.inputPCMFormat.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
        //TODO:check if size of SInt16 is always suitable
        settings.inputPCMFormat.mBitsPerChannel = 8 * sizeof(SInt16);
        settings.inputPCMFormat.mChannelsPerFrame = settings.outputFormat.mChannelsPerFrame;
        //TODO:check if this is suitable for both interleaved/noninterleaved
        settings.inputPCMFormat.mBytesPerPacket = settings.inputPCMFormat.mBytesPerFrame = settings.inputPCMFormat.mChannelsPerFrame*sizeof(SInt16);
        settings.inputPCMFormat.mFramesPerPacket = 1;
    }
    NSLog(@"Client data format:%@",[self descriptionForAudioFormat:settings.inputPCMFormat]);
    
    CheckError(ExtAudioFileSetProperty(settings.inputFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       sizeof(settings.inputPCMFormat),
                                       &settings.inputPCMFormat),
               "Setting client data format of input file failed");
    
    //TODO:check if necessary to set client data format of output file
    
    printf("Start converting...\n");
    startConvert(&settings);
    
    ExtAudioFileDispose(settings.inputFile);
    //AudioFileClose function is needed, or else for .wav output file the duration will be 0
    AudioFileClose(settings.outputFile);
    return YES;
}

-(NSString*)descriptionForAudioFormat:(AudioStreamBasicDescription) audioFormat
{
    NSMutableString *description = [NSMutableString new];
    
    // From https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/ConstructingAudioUnitApps/ConstructingAudioUnitApps.html (Listing 2-8)
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (audioFormat.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    [description appendString:@"\n"];
    [description appendFormat:@"Sample Rate:         %10.0f \n",  audioFormat.mSampleRate];
    [description appendFormat:@"Format ID:           %10s \n",    formatIDString];
    [description appendFormat:@"Format Flags:        %10X \n",    (unsigned int)audioFormat.mFormatFlags];
    [description appendFormat:@"Bytes per Packet:    %10d \n",    (unsigned int)audioFormat.mBytesPerPacket];
    [description appendFormat:@"Frames per Packet:   %10d \n",    (unsigned int)audioFormat.mFramesPerPacket];
    [description appendFormat:@"Bytes per Frame:     %10d \n",    (unsigned int)audioFormat.mBytesPerFrame];
    [description appendFormat:@"Channels per Frame:  %10d \n",    (unsigned int)audioFormat.mChannelsPerFrame];
    [description appendFormat:@"Bits per Channel:    %10d \n",    (unsigned int)audioFormat.mBitsPerChannel];
    
    // Add flags (supposing standard flags).
    [description appendString:[self descriptionForStandardFlags:audioFormat.mFormatFlags]];
    
    return [NSString stringWithString:description];
}

-(NSString*)descriptionForStandardFlags:(UInt32) mFormatFlags
{
    NSMutableString *description = [NSMutableString new];
    
    if (mFormatFlags & kAudioFormatFlagIsFloat)
    { [description appendString:@"kAudioFormatFlagIsFloat \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsBigEndian)
    { [description appendString:@"kAudioFormatFlagIsBigEndian \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsSignedInteger)
    { [description appendString:@"kAudioFormatFlagIsSignedInteger \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsPacked)
    { [description appendString:@"kAudioFormatFlagIsPacked \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsAlignedHigh)
    { [description appendString:@"kAudioFormatFlagIsAlignedHigh \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsNonInterleaved)
    { [description appendString:@"kAudioFormatFlagIsNonInterleaved \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsNonMixable)
    { [description appendString:@"kAudioFormatFlagIsNonMixable \n"]; }
    if (mFormatFlags & kAudioFormatFlagsAreAllClear)
    { [description appendString:@"kAudioFormatFlagsAreAllClear \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsFloat)
    { [description appendString:@"kLinearPCMFormatFlagIsFloat \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsBigEndian)
    { [description appendString:@"kLinearPCMFormatFlagIsBigEndian \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsSignedInteger)
    { [description appendString:@"kLinearPCMFormatFlagIsSignedInteger \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsPacked)
    { [description appendString:@"kLinearPCMFormatFlagIsPacked \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsAlignedHigh)
    { [description appendString:@"kLinearPCMFormatFlagIsAlignedHigh \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved)
    { [description appendString:@"kLinearPCMFormatFlagIsNonInterleaved \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsNonMixable)
    { [description appendString:@"kLinearPCMFormatFlagIsNonMixable \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsSampleFractionShift)
    { [description appendString:@"kLinearPCMFormatFlagsSampleFractionShift \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsSampleFractionMask)
    { [description appendString:@"kLinearPCMFormatFlagsSampleFractionMask \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsAreAllClear)
    { [description appendString:@"kLinearPCMFormatFlagsAreAllClear \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_16BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_16BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_20BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_20BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_24BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_24BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_32BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_32BitSourceData \n"]; }
    
    return [NSString stringWithString:description];
}


@end
