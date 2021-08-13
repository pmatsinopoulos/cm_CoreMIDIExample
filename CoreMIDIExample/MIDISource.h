//
//  MIDISource.h
//  CoreMIDIExample
//
//  Created by Panayotis Matsinopoulos on 13/8/21.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIDISource : NSObject
@property MIDIEndpointRef source;
@property NSString *name;
@end

NS_ASSUME_NONNULL_END
