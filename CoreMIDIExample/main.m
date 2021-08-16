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

void ReleaseResources(AppState *appState,
                      AudioUnit defaultOutputAudioUnit,
                      AudioUnit reverbAudioUnit,
                      AudioUnit dlsSynthAudioUnit) {
  CheckError(MIDIPortDisconnectSource(appState->inPort, appState->source),
             "Disconnecting port from source");
  CheckError(MIDIPortDispose(appState->inPort),
             "Disposing of the MIDI port");
  CheckError(MIDIClientDispose(appState->client),
             "Disposing of the MIDI client");
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
  NSPrint(@"Which source do you want to connect to? [1-%lu] :", numberOfSources);
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

void ConnectToMIDISource(AppState *appState, ItemCount sourceIndex) {
  appState->source = MIDIGetSource(sourceIndex - 1);
  CheckError(MIDIPortConnectSource(appState->inPort,
                                   appState->source,
                                   appState),
             "Connecting port to source");
}

void ProcessEvent(const MIDIEventList *evtlist, void *srcConnRefCon) {
  AppState *appState = (AppState *)srcConnRefCon;
  MIDIEventPacket *packet = (MIDIEventPacket*)evtlist->packet;

  while(packet && packet->wordCount) {
    Byte messageType = (packet->words[0] & 0xF0000000) >> 28;
    if (messageType == 0x02) { // MIDI 1.0 Voice Channel Message
      // We work with the first word only for MIDI 1.0 Voice Channel Messages
      Byte status = (Byte)((packet->words[0] & 0x00FF0000) >> 16);
      Byte midiCommand = status >> 4; // the command is the 4 left-most bits
      Byte midiChannel = status & 0x0F; // the channel is the 4 right-most bits
      NSLog(@"status %x, command %d, channel %d", status, midiCommand, midiChannel);
      
      if (midiCommand == NOTE_ON || midiCommand == NOTE_OFF) {
        Byte note = (Byte)((packet->words[0] & 0x00007F00) >> 8);
        Byte velocity = (Byte)(packet->words[0] & 0x0000007F);

        NSLog(@"Note: %u, velocity: %u", note, velocity);
        CheckError(MusicDeviceMIDIEvent(appState->dlsSynthAudioUnit, status, note, velocity, 0),
                   "Sending event to DLS synth unit");
      }
    }
    packet = MIDIEventPacketNext(packet);
  }
}

MIDIPortRef CreateMIDIInputPort(MIDIClientRef client) {
  MIDIReceiveBlock receiveBlock = ^void (const MIDIEventList *evtlist, void *srcConnRefCon) {
    ProcessEvent(evtlist, srcConnRefCon);
  };
  
  MIDIPortRef inPort;
  CheckError(MIDIInputPortCreateWithProtocol(client,
                                             CFSTR("Input Port"),
                                             kMIDIProtocol_1_0,
                                             &inPort,
                                             receiveBlock),
             "Creating MIDI Input Port");
  return inPort;
}

void SetupMIDI(AppState *appState) {
  CheckError(MIDIClientCreate(CFSTR("Core MIDI Example"),
//                              MIDIStateChangesNotify,
                              NULL,
                              NULL,
                              &(appState->client)),
             "Creating MIDI Client Session");
  
  appState->inPort = CreateMIDIInputPort(appState->client);
        
  ItemCount numberOfSources = 0;
  
  ListMIDISources(&numberOfSources);
  
  ItemCount sourceIndex = AskUserWhichMIDISource(numberOfSources);
    
  ConnectToMIDISource(appState, sourceIndex);
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
    
    ReleaseResources(&appState,
                     defaultOutputAudioUnit,
                     reverbAudioUnit,
                     appState.dlsSynthAudioUnit);
    
    NSPrint(@"Bye!\n");
  }
  return 0;
}
