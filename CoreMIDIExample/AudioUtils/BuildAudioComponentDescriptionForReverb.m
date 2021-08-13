//
//  BuildAudioComponentDescriptionForReverb.m
//  CoreMIDIExample
//
//  Created by Panayotis Matsinopoulos on 13/8/21.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

void BuildAudioComponentDescriptionForReverb(AudioComponentDescription *oAudioComponentDescription) {
  oAudioComponentDescription->componentType = kAudioUnitType_Effect;
  oAudioComponentDescription->componentSubType = kAudioUnitSubType_MatrixReverb;
  oAudioComponentDescription->componentManufacturer = kAudioUnitManufacturer_Apple;
}
