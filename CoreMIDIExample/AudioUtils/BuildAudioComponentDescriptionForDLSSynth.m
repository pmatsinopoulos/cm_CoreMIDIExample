//
//  BuildAudioComponentDescriptionForDLSSynth.m
//  CoreMIDIExample
//
//  Created by Panayotis Matsinopoulos on 12/8/21.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "BuildAudioComponentDescriptionForDLSSynth.h"

void BuildAudioComponentDescriptionForDLSSynth(AudioComponentDescription *oAudioComponentDescription) {
  oAudioComponentDescription->componentType = kAudioUnitType_MusicDevice;
  oAudioComponentDescription->componentSubType = kAudioUnitSubType_DLSSynth;
  oAudioComponentDescription->componentManufacturer = kAudioUnitManufacturer_Apple;
}
