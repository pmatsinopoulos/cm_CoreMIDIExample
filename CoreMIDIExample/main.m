//
//  main.m
//  CoreMIDIExample
//
//  Created by Panayotis Matsinopoulos on 12/8/21.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CheckError.h"
#import "NSPrint.h"
#import "AppState.h"
#import "BuildAudioComponentDescriptionForDefaultOutput.h"
#import "FindAudioComponent.h"
#import "BuildAudioComponentDescriptionForDLSSynth.h"
#import "BuildAudioComponentDescriptionForReverb.h"

#define NOTE_ON  0x09
#define NOTE_OFF 0x08

AudioUnit SetUpDefaultOutputAudioUnit(void) {
  AudioComponentDescription outputDefaultDescription = {0};
  
  BuildAudioComponentDescriptionForDefaultOutput(&outputDefaultDescription);
    
  AudioComponent defaultOutputAudioComponent = FindAudioComponent(outputDefaultDescription);
    
  AudioUnit defaultOutputAudioUnit;
    
  CheckError(AudioComponentInstanceNew(defaultOutputAudioComponent,
                                       &defaultOutputAudioUnit),
             "Instantiating the Default Output Audio Unit");
  
  CheckError(AudioUnitInitialize(defaultOutputAudioUnit), "Initializing the defaultOutputAudioUnit");

  return defaultOutputAudioUnit;
}

AudioUnit SetUpDLSSynthAudioUnit(void) {
  AudioComponentDescription dlsSynthDescription = {0};
  
  BuildAudioComponentDescriptionForDLSSynth(&dlsSynthDescription);
    
  AudioComponent dlsSynthAudioComponent = FindAudioComponent(dlsSynthDescription);
    
  AudioUnit dlsSynthAudioUnit;
    
  CheckError(AudioComponentInstanceNew(dlsSynthAudioComponent,
                                       &dlsSynthAudioUnit),
             "Instantiating the DLS Synth Audio Unit");
  
  CheckError(AudioUnitInitialize(dlsSynthAudioUnit), "Initializing the dlsSynthAudioUnit");

  return dlsSynthAudioUnit;
}

AudioUnit SetUpReverbAudioUnit(void) {
  AudioComponentDescription reverbDescription = {0};
  
  BuildAudioComponentDescriptionForReverb(&reverbDescription);
    
  AudioComponent reverbAudioComponent = FindAudioComponent(reverbDescription);
    
  AudioUnit reverbAudioUnit;
    
  CheckError(AudioComponentInstanceNew(reverbAudioComponent,
                                       &reverbAudioUnit),
             "Instantiating the Reverb Audio Unit");
  
  CheckError(AudioUnitInitialize(reverbAudioUnit), "Initializing the reverbAudioUnit");

  return reverbAudioUnit;
}

void ConnectUnitsTogether(AudioUnit sourceAudioUnit, AudioUnit destinationAudioUnit) {
  AudioUnitConnection connection;
  connection.destInputNumber = 0;
  connection.sourceAudioUnit = sourceAudioUnit;
  connection.sourceOutputNumber = 0;
  
  CheckError(AudioUnitSetProperty(destinationAudioUnit,
                                  kAudioUnitProperty_MakeConnection,
                                  kAudioUnitScope_Input,
                                  0,
                                  &connection,
                                  sizeof(AudioUnitConnection)),
             "connecting source audio unit to destination audio unit");
}

void StartDefaultOutputUnit(AudioUnit defaultOutputAudioUnit) {
  // need to start the default output unit
  CheckError(AudioOutputUnitStart(defaultOutputAudioUnit),
             "Starting the Output Audio Unit");
}

void ReleaseAudioUnit(AudioUnit inAudioUnit) {
  CheckError(AudioUnitUninitialize(inAudioUnit), "Uninitializing the Audio Unit");
  CheckError(AudioComponentInstanceDispose(inAudioUnit), "Disposing the Audio Unit");
}

void StopAudioOutputUnit(AudioUnit inAudioUnit) {
  CheckError(AudioOutputUnitStop(inAudioUnit), "Stopping the Output Audio Unit");
  ReleaseAudioUnit(inAudioUnit);
}

void ReleaseResources(AudioUnit defaultOutputAudioUnit,
                      AudioUnit reverbAudioUnit,
                      AudioUnit dlsSynthAudioUnit) {
  StopAudioOutputUnit(defaultOutputAudioUnit);
  ReleaseAudioUnit(reverbAudioUnit);
  ReleaseAudioUnit(dlsSynthAudioUnit);
}

//void MIDIStateChangesNotify(const MIDINotification *message, void *refCon) {
//  const int MAX_MESSAGE_SIZE = 128;
//  char strMessage[MAX_MESSAGE_SIZE];
//  memset(strMessage, 0, MAX_MESSAGE_SIZE);
//
//  switch (message->messageID) {
//    case kMIDIMsgSetupChanged:
//      strcpy(strMessage, "kMIDIMsgSetupChanged");
//      break;
//    case kMIDIMsgObjectAdded:
//      strcpy(strMessage, "kMIDIMsgObjectAdded");
//      break;
//    case kMIDIMsgObjectRemoved:
//      strcpy(strMessage, "kMIDIMsgObjectRemoved");
//      break;
//    case kMIDIMsgPropertyChanged:
//      strcpy(strMessage, "kMIDIMsgPropertyChanged");
//      break;
//    case kMIDIMsgThruConnectionsChanged:
//      strcpy(strMessage, "kMIDIMsgThruConnectionsChanged");
//      break;
//    case kMIDIMsgSerialPortOwnerChanged:
//      strcpy(strMessage, "kMIDIMsgSerialPortOwnerChanged");
//      break;
//    case kMIDIMsgIOError:
//      strcpy(strMessage, "kMIDIMsgIOError");
//      break;
//
//    default:
//      strcpy(strMessage, "Unknow MIDI Message");
//      break;
//  }
//  NSLog(@"MIDIStateChangesNotify(): message %s", strMessage);
//}

void MIDIReadNotify(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon) {
  AppState *appState = (AppState *)readProcRefCon;
  MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
  while(packet && packet->length) {
    Byte *data = packet->data;
    Byte midiStatus = data[0];
    Byte midiCommand = midiStatus >> 4; // the command is the 4 left-most bits
    Byte midiChannel = midiStatus & 0x0F; // the channel is the 4 right-most bits
    
    NSLog(@"Channel: %u, Command: %u", midiChannel, midiCommand);
    
    if (midiCommand == NOTE_ON || midiCommand == NOTE_OFF) {
      Byte note = data[1] & 0x7F;
      Byte velocity = data[2] & 0x7F;
      NSLog(@"Note: %u, velocity: %u", note, velocity);
      CheckError(MusicDeviceMIDIEvent(appState->dlsSynthAudioUnit, midiStatus, note, velocity, 0),
                 "Sending event to DLS synth unit");
    }
    packet = MIDIPacketNext(packet);
  }
}

ItemCount GetNumberOfMIDISources(void) {
  ItemCount numberOfSources = MIDIGetNumberOfSources();
  if (numberOfSources == 0) {
    NSLog(@"Can't find any MIDI Sources! Are you sure you have them connected to your host system?");
    exit(1);
  }
  return numberOfSources;
}

void ListMIDISources(ItemCount *oNumberOfSources) {
  *oNumberOfSources = GetNumberOfMIDISources();
  
  NSPrint(@"Number of sources found %lu\n", *oNumberOfSources);
  
  for (ItemCount i = 0; i < *oNumberOfSources; i++) {
    MIDIEndpointRef source = MIDIGetSource(i);
    
    CFStringRef name;
    
    CheckError(MIDIObjectGetStringProperty(source,
                                           kMIDIPropertyName,
                                           &name),
               "Getting the name of the source");
    
    NSPrint(@"MIDI Source: %@, with index: %lu\n", name, i + 1);
            
    CFRelease(name);
  }
}

ItemCount AskUserWhichMIDISource(ItemCount numberOfSources) {
  NSPrint(@"Which source to you want to connect to? [1-%lu] :", numberOfSources);
  ItemCount sourceIndex = -1;
  scanf("%lu", &sourceIndex);
  fflush(stdin);
  if (sourceIndex < 1 || sourceIndex > numberOfSources) {
    fprintf(stderr, "Cannot connect this source: %lu\n", sourceIndex);
    exit(1);
  }
  NSPrint(@"Will connect source %lu\n", sourceIndex);

  return sourceIndex;
}

void ConnectToMIDISource(ItemCount sourceIndex, MIDIPortRef port) {
  MIDIEndpointRef source = MIDIGetSource(sourceIndex - 1);
  CheckError(MIDIPortConnectSource(port,
                                   source,
                                   NULL),
             "Connecting port to source");
}

void SetupMIDI(AppState *appState) {
  MIDIClientRef client;
  CheckError(MIDIClientCreate(CFSTR("Core MIDI Example"),
//                              MIDIStateChangesNotify,
                              NULL,
                              NULL,
                              &client),
             "Creating MIDI Client Session");
  
  MIDIPortRef inPort;
  CheckError(MIDIInputPortCreate(client,
                                 CFSTR("Input Port"),
                                 MIDIReadNotify,
                                 appState,
                                 &inPort),
             "Creating MIDI Input Port");
  
  ItemCount numberOfSources = 0;
  
  ListMIDISources(&numberOfSources);
  
  ItemCount sourceIndex = AskUserWhichMIDISource(numberOfSources);
    
  ConnectToMIDISource(sourceIndex, inPort);
}

int main(int argc, const char * argv[]) {
  @autoreleasepool {
    AppState appState = {0};
    
    AudioUnit defaultOutputAudioUnit = SetUpDefaultOutputAudioUnit();
    
    AudioUnit reverbAudioUnit = SetUpReverbAudioUnit();

    appState.dlsSynthAudioUnit = SetUpDLSSynthAudioUnit();
    
    ConnectUnitsTogether(appState.dlsSynthAudioUnit, reverbAudioUnit);
    
    ConnectUnitsTogether(reverbAudioUnit, defaultOutputAudioUnit);
    
    SetupMIDI(&appState);
    
    StartDefaultOutputUnit(defaultOutputAudioUnit);
    
    NSPrint(@"Tap keys on your MIDI controller...Click <Enter> to stop\n");
    getchar();
//    while(true) {
//      CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
//    }
    
    ReleaseResources(defaultOutputAudioUnit,
                     reverbAudioUnit,
                     appState.dlsSynthAudioUnit);
    
    NSPrint(@"Bye!\n");
  }
  return 0;
}
