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
    ExtAudioFileRef               outputFile;
    
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
    UInt32 framesPerBuffer = sizePerBuffer/sizeof(SInt16);
    
    // allocate destination buffer
    UInt8 *outputBuffer = (UInt8 *)malloc(sizeof(UInt8) * sizePerBuffer);
    
    settings->outputFileStartingPacketCount = 0;
    while (1) {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers              = 1;
        outputBufferList.mBuffers[0].mNumberChannels = settings->outputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize   = sizePerBuffer;
        outputBufferList.mBuffers[0].mData           = outputBuffer;
        
        UInt32 framesCount = framesPerBuffer;
        
        CheckError(ExtAudioFileRead(settings->inputFile,
                                    &framesCount,
                                    &outputBufferList),
                   "ExtAudioFileRead failed");
                
        if (framesCount==0) {
            printf("Done reading from input file\n");
            return;
        }
        NSLog(@"frames read:%d",framesCount);
        
        CheckError(ExtAudioFileWrite(settings->outputFile,
                                     framesCount,
                                     &outputBufferList),
                   "ExtAudioFileWrite failed");
        //NSLog(@"packet count:%lld",settings->outputFileStartingPacketCount);
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
    
    [self validateInput:&settings];
    
    settings.outputFormat.mSampleRate       = self.outputSampleRate;
    settings.outputFormat.mBitsPerChannel   = self.outputBitDepth;
    if (self.outputFormatID==kAudioFormatMPEG4AAC) {
        settings.outputFormat.mBitsPerChannel = 0;
    }
    settings.outputFormat.mChannelsPerFrame = self.outputNumberChannels;
    settings.outputFormat.mFormatID         = self.outputFormatID;
    
    if (self.outputFormatID==kAudioFormatLinearPCM) {
        settings.outputFormat.mBytesPerFrame   = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
        settings.outputFormat.mBytesPerPacket  = settings.outputFormat.mBytesPerFrame;
        settings.outputFormat.mFramesPerPacket = 1;
        settings.outputFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        //the aiff type only support big-endian
        if (self.outputFileType==kAudioFileAIFFType || self.outputFileType==kAudioFileSoundDesigner2Type ||self.outputFileType==kAudioFileAIFCType) {
            settings.outputFormat.mFormatFlags |= kAudioFormatFlagIsBigEndian;
        }
    }else{
        //Set compressed format
        if (self.outputFormatID==kAudioFormatMACE3) {
            //settings.outputFormat.mBitsPerChannel = 0;
            settings.outputFormat.mChannelsPerFrame = 0;
        }
        UInt32 size = sizeof(settings.outputFormat);
        CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                          0,
                                          NULL,
                                          &size,
                                          &settings.outputFormat),
                   "AudioFormatGetProperty kAudioFormatProperty_FormatInfo failed");
    }
    NSLog(@"output format:%@",[self descriptionForAudioFormat:settings.outputFormat]);
    
    //Create output file
    //if output file path is invalid, this returns an error with 'wht?'
    NSURL* outputURL = [NSURL fileURLWithPath:self.outputFile];
    
    //create output file
    CheckError(ExtAudioFileCreateWithURL((__bridge CFURLRef)outputURL,
                                         self.outputFileType,
                                         &settings.outputFormat,
                                         NULL,
                                         kAudioFileFlags_EraseFile,
                                         &settings.outputFile),
               "Create output file failed, the output file type and output format pair may not match");
    
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
    
    //If the file has a client data format, then the audio data in ioData is translated from the client format to the file data format, via theExtAudioFile's internal AudioConverter.
    CheckError(ExtAudioFileSetProperty(settings.outputFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       sizeof(settings.inputPCMFormat),
                                       &settings.inputPCMFormat),
               "Setting client data format of output file failed");
    
    printf("Start converting...\n");
    startConvert(&settings);
    
    ExtAudioFileDispose(settings.inputFile);
    //AudioFileClose/ExtAudioFileDispose function is needed, or else for .wav output file the duration will be 0
    ExtAudioFileDispose(settings.outputFile);
    return YES;
}

//Check if the input combination is valid
-(void)validateInput:(ExtAudioConverterSettings*)settigs{
    //Set default output format
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
        //caf type is the most powerful file format
        self.outputFileType = kAudioFileCAFType;
    }
    
    BOOL valid = YES;
    //The file format and data format match documentatin is at: https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/CoreAudioOverview/SupportedAudioFormatsMacOSX/SupportedAudioFormatsMacOSX.html
    switch (self.outputFileType) {
        case kAudioFileWAVEType:{//for wave file format
            //WAVE file type only support PCM, alaw and ulaw
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatALaw || self.outputFormatID==kAudioFormatULaw;
            break;
        }
        case kAudioFileAIFFType:{
            //AIFF only support PCM format
            valid = self.outputFormatID==kAudioFormatLinearPCM;
            break;
        }
        case kAudioFileAAC_ADTSType:{
            //aac only support aac data format
            valid = self.outputFormatID==kAudioFormatMPEG4AAC;
            break;
        }
        case kAudioFileAC3Type:{
            //convert from PCM to ac3 format is not supported
            valid = NO;
            break;
        }
        case kAudioFileAIFCType:{
            //TODO:kAudioFileAIFCType together with kAudioFormatMACE3/kAudioFormatMACE6/kAudioFormatQDesign2/kAudioFormatQUALCOMM pair failed
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatULaw || self.outputFormatID==kAudioFormatALaw || self.outputFormatID==kAudioFormatMACE3 || self.outputFormatID==kAudioFormatMACE6 || self.outputFormatID==kAudioFormatAppleIMA4 || self.outputFormatID==kAudioFormatQDesign2 || self.outputFormatID==kAudioFormatQUALCOMM;
            break;
        }
        case kAudioFileCAFType:{
            //caf file type support almost all data format
            //TODO:not all foramt are supported, check them out
            valid = YES;
            break;
        }
        case kAudioFileMP3Type:{
            NSLog(@"Encoded from PCM to MP3 format is not supported yet.");
            valid = NO;
            break;
        }
        case kAudioFileMPEG4Type:{
            valid = self.outputFormatID==kAudioFormatMPEG4AAC;
            break;
        }
        case kAudioFileM4AType:{
            valid = self.outputFormatID==kAudioFormatMPEG4AAC || self.outputFormatID==kAudioFormatAppleLossless;
            break;
        }
        case kAudioFileNextType:{
            //TODO:kAudioFileNextType/kAudioFormatLinearPCM pair failed
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatULaw;
            break;
        }
        case kAudioFileSoundDesigner2Type:{
            valid = self.outputFormatID==kAudioFormatLinearPCM;
            break;
        }
            //TODO:check iLBC format
        default:
            break;
    }
    
    if (!valid) {
        NSLog(@"the file format and data format pair is not valid");
        exit(-1);
    }

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
    [description appendFormat:@"Format Flags:        %10d \n",    (unsigned int)audioFormat.mFormatFlags];
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
