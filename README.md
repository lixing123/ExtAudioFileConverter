# ExtAudioConverter
An iOS project to convert audio from any format to any format.
ExtAuioConverter is an implementation of the afconvert command on OS X, 
so this readme file uses some hints of afconvert help documentation. For example, LEI16 means little-endian signed int with 16 bit depth.

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

Set channel count:
converter.outputNumberChannels = 2;

Set bit depth:
converter.outputBitDepth = BitDepth_16;

Set data format:
converter.outputFormatID = kAudioFormatLinearPCM;

Set file format:
converter.outputFileType = kAudioFileWAVEType;


Some parameter combinations is impossible, like mp3 file format together with wav data format, so please take care to check if the combinations are correct.



Available Input file type/format type:
mp3/mp3(tested);
caf/wav(tested);


Available Output file type/format type:
wav/LEI16(tested);
wav/LEI32(tested);
(mp3 output format will be supported in the future)
