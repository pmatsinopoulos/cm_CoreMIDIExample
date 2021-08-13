//
//  BuildAudioComponentDescriptionForDefaultOutput.c
//  ConnectAudioUnitsTogether
//
//  Created by Panayotis Matsinopoulos on 30/7/21.
//

#import <AudioToolbox/AudioToolbox.h>
#import "BuildAudioComponentDescriptionForDefaultOutput.h"

void BuildAudioComponentDescriptionForDefaultOutput(AudioComponentDescription *oAudioComponentDescription) {
  oAudioComponentDescription->componentType = kAudioUnitType_Output;
  oAudioComponentDescription->componentSubType = kAudioUnitSubType_DefaultOutput;
  oAudioComponentDescription->componentManufacturer = kAudioUnitManufacturer_Apple;
}

