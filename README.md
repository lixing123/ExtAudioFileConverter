## An iOS project to convert audio from any format to any format.</br>
ExtAudioConverter is an implementation of the afconvert command on OS X, </br>
so this readme file uses some hints of afconvert help documentation. For example, LEI16 means little-endian signed int with 16 bit depth.

### How to use:

1. Link Binary with Library "AudioToolbox.framework";

2. Add "ExtAudioConverter.h" and "ExtAudioConverter.m" to your project;

3. Test:
```objective-c
ExtAudioConverter* converter = [[ExtAudioConverter alloc] init];
converter.inputFile =  @"/Users/lixing/Desktop/input.caf";
converter.outputFile = @"/Users/lixing/Desktop/output.wav";
[converter convert];
```
The following parameters are optional:

Set the sample rate:</br>
```objective-c
converter.outputSampleRate = 44100;
```
Set channel count:</br>
```objective-c
converter.outputNumberChannels = 2;
```

Set bit depth:</br>
```objective-c
converter.outputBitDepth = BitDepth_16;
```
Set data format:</br>
```objective-c
converter.outputFormatID = kAudioFormatLinearPCM;
```
Set file format:</br>
```objective-c
converter.outputFileType = kAudioFileWAVEType;
```

Some parameter combinations is impossible, like mp3 file format together with wav data format.</br>
The valid file type/data format pair is described on the Apple documentation</br> https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/CoreAudioOverview/SupportedAudioFormatsMacOSX/SupportedAudioFormatsMacOSX.html



### For mp3 format conversion
Apple doesn't include the MP3 encode algorithm in its APIs, but include the decode algorithm.</br>
~~So we can now convert from mp3 file to other formats, but can't convert to mp3 format.~~</br>
~~We will use other open source mp3 codec, like lame, to convert to mp3 format.~~</br>
We have now supported conversion to mp3 format, using the famous lame mp3 codec.

If you have any questions, please commit an issue, or mail me:shangwangwanwan@gmail.com.
