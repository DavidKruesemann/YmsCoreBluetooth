//
// Copyright 2013 Yummy Melon Software LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Author: Charles Y. Choi <charles.choi@yummymelon.com>
//

#import "DEABaseService.h"
#import "YMSCBCharacteristic.h"

@implementation DEABaseService

- (void)requestConfig {
    [self readValueForCharacteristicName:@"config"];
    //[self writeByte:0x1 forCharacteristicName:@"config" type:CBCharacteristicWriteWithResponse];
}

- (NSData *)responseConfig {
    YMSCBCharacteristic *yc = self.characteristicDict[@"config"];
    NSData *data = yc.cbCharacteristic.value;
    return data;
}

- (void)turnOff {
    [self writeByte:0x0 forCharacteristicName:@"config" type:CBCharacteristicWriteWithResponse];
    [self setNotifyValue:NO forCharacteristicName:@"data"];
    self.isOn = NO;
}

- (void)turnOn {
    [self writeByte:0x1 forCharacteristicName:@"config" type:CBCharacteristicWriteWithResponse];
    [self setNotifyValue:YES forCharacteristicName:@"data"];
    self.isOn = YES;
}


@end
