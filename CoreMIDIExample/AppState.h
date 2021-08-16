//
//  AppState.h
//  CoreMIDIExample
//
//  Created by Panayotis Matsinopoulos on 12/8/21.
//

#ifndef AppState_h
#define AppState_h

#import <AudioToolbox/AudioToolbox.h>

typedef struct AppState {
  AudioUnit dlsSynthAudioUnit;
  MIDIClientRef client;
  MIDIPortRef inPort;
  MIDIEndpointRef source;
} AppState;

#endif /* AppState_h */
