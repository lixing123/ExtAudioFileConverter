# ExtAudioConverter
An iOS project trying to convert audio from any format to any format

How to use:

1\ Link Binary with Library "AudioToolbox.framework";

2\Add "ExtAudioConverter.h" and "ExtAudioConverter.m" to your project;

3\Test:

ExtAudioConverter* converter = [[ExtAudioConverter alloc] init];
converter.inputFile =  @"/Users/lixing/Desktop/input.caf";
converter.outputFile = @"/Users/lixing/Desktop/output.wav";
[converter convert];

4\
The following parameters are optional:
Set the sample rate:
    converter.outputSampleRate = 44100;
Set channel count
    converter.outputNumberChannels = 2;
Set bit depth
    converter.outputBitDepth = BitDepth_16;
Set data format
    converter.outputFormatID = kAudioFormatLinearPCM;
Set file format
    converter.outputFileType = kAudioFileWAVEType;
