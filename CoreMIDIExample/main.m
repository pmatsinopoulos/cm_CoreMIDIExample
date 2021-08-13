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

void ConnectUnitsTogether(AudioUnit dlsSynthAudioUnit, AudioUnit defaultOutputAudioUnit) {
  AudioUnitConnection connection;
  connection.destInputNumber = 0;
  connection.sourceAudioUnit = dlsSynthAudioUnit;
  connection.sourceOutputNumber = 0;
  
  CheckError(AudioUnitSetProperty(defaultOutputAudioUnit,
                                  kAudioUnitProperty_MakeConnection,
                                  kAudioUnitScope_Input,
                                  0,
                                  &connection,
                                  sizeof(AudioUnitConnection)),
             "connecting dls synth audio unit to default output unit");
}

void StartDefaultOutputUnit(AudioUnit defaultOutputAudioUnit) {
  // need to start the default output unit
  CheckError(AudioOutputUnitStart(defaultOutputAudioUnit),
             "Starting the Output Audio Unit");
}

void StopAudioOutputUnit(AudioUnit inAudioUnit) {
  CheckError(AudioOutputUnitStop(inAudioUnit), "Stopping the Output Audio Unit");
  CheckError(AudioUnitUninitialize(inAudioUnit), "Uninitializing the Output Audio Unit");
  CheckError(AudioComponentInstanceDispose(inAudioUnit), "Disposing the Output Audio Unit");
}

void StopDLSSynthAudioUnit(AudioUnit dlsSynthAudioUnit) {
  CheckError(AudioUnitUninitialize(dlsSynthAudioUnit), "Uninitializing the DLSSynth Audio Unit");
  CheckError(AudioComponentInstanceDispose(dlsSynthAudioUnit), "Disposing the DLSSynth Audio Unit");
}

void ReleaseResources(AudioUnit defaultOutputAudioUnit, AudioUnit dlsSynthAudioUnit) {
  StopAudioOutputUnit(defaultOutputAudioUnit);
  StopDLSSynthAudioUnit(dlsSynthAudioUnit);
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
  
  ItemCount numberOfSources = MIDIGetNumberOfSources();
  if (numberOfSources == 0) {
    NSLog(@"Can't find any MIDI Sources! Are you sure you have them connected to your host system?");
    exit(1);
  }
  
  NSLog(@"Number of sources found %lu", numberOfSources);
  // TODO: Maybe create a dictionary of objects. The key can be the string version of the
  // index and the value can be an object with 2 members: the MIDIEndpointRef and the Name
  // This should be a Mutable Dictionary
  MIDIEndpointRef *sources = malloc(numberOfSources * sizeof(MIDIEndpointRef));
  
  for (ItemCount i = 0; i < numberOfSources; i++) {
    sources[i] = MIDIGetSource(i);
    
    // TODO: Use NSStrings maybe? So, I will not have to release things?
    CFStringRef name;
    
    CheckError(MIDIObjectGetStringProperty(sources[i],
                                           kMIDIPropertyName,
                                           &name),
               "Getting the name of the source");
    
    NSLog(@"MIDI Source %@, with index: %lu", name, i + 1);
            
    CFRelease(name);
  }
  
  printf("Which source to you want to connect to? [1-%lu] :", numberOfSources);
  ItemCount sourceIndex = -1;
  scanf("%lu", &sourceIndex);
  fflush(stdin);
  if (sourceIndex < 1 || sourceIndex > numberOfSources) {
    fprintf(stderr, "Cannot connect this source: %lu\n", sourceIndex);
    exit(1);
  }
  printf("Will connect source %lu\n", sourceIndex);
  
  MIDIEndpointRef source = sources[sourceIndex - 1];
  CheckError(MIDIPortConnectSource(inPort,
                                   source,
                                   NULL),
             "Connecting port to source");
  
  free(sources);
  sources = NULL;
}

int main(int argc, const char * argv[]) {
  @autoreleasepool {
    AppState appState = {0};
    
    AudioUnit defaultOutputAudioUnit = SetUpDefaultOutputAudioUnit();
    
    appState.dlsSynthAudioUnit = SetUpDLSSynthAudioUnit();
    
    ConnectUnitsTogether(appState.dlsSynthAudioUnit, defaultOutputAudioUnit);
    
    SetupMIDI(&appState);
    
    StartDefaultOutputUnit(defaultOutputAudioUnit);
    
    NSPrint(@"Tap keys on your MIDI controller...Click <Enter> to stop\n");
    getchar();
//    while(true) {
//      CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
//    }
    
    ReleaseResources(defaultOutputAudioUnit, appState.dlsSynthAudioUnit);
    
    NSPrint(@"Bye\n");
  }
  return 0;
}
