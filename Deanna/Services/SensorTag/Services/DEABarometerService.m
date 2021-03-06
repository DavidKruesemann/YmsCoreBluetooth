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


#import "DEABarometerService.h"
#import "YMSCBCharacteristic.h"

@implementation DEABarometerService

double calcBarTmp(int16_t t_r, uint16_t c1, uint16_t c2) {
    int32_t t_a;
    
    
    t_a = (((((int32_t)c1 * t_r)/0x100) +
            ((int32_t)c2 * 0x40))*100
           ) / 0x10000;
     

    return (double)t_a/100.0;
}


double calcBarPress(int16_t t_r,
                    uint16_t p_r,
                    uint16_t c3,
                    uint16_t c4,
                    int16_t c5,
                    int16_t c6,
                    int16_t c7,
                    int16_t c8) {
    
    int32_t p_a, S, O;
    
    //calculate pressure
    S=c3+(((int32_t)c4*t_r)/0x20000)+(((((int32_t)c5*t_r)/0x8000)*t_r)/0x80000);
    O=c6*0x4000+(((int32_t)c7*t_r)/8)+(((((int32_t)c8*t_r)/0x8000)*t_r)/16);
    p_a=(S*p_r+O)/0x4000;
    
    // Unit: Pascal (Pa)
    return (double)p_a;
}
                    

- (id)initWithName:(NSString *)oName
            baseHi:(int64_t)hi
            baseLo:(int64_t)lo {
    self = [super initWithName:oName
                        baseHi:hi
                        baseLo:lo];

    if (self) {
        [self addCharacteristic:@"service" withOffset:kSensorTag_BAROMETER_SERVICE];
        [self addCharacteristic:@"data" withOffset:kSensorTag_BAROMETER_DATA];
        [self addCharacteristic:@"config" withOffset:kSensorTag_BAROMETER_CONFIG];
        [self addCharacteristic:@"calibration" withOffset:kSensorTag_BAROMETER_CALIBRATION];
        _isCalibrating = NO;
    }
    return self;
}

- (void)updateCharacteristic:(YMSCBCharacteristic *)yc {
    if ([yc.name isEqualToString:@"data"]) {

        if (self.isCalibrated == NO) {
            return;
        }

        NSData *data = yc.cbCharacteristic.value;
        
        char val[data.length];
        [data getBytes:&val length:data.length];
        
        
        int16_t v0 = val[0];
        int16_t v1 = val[1];
        int16_t v2 = val[2];
        int16_t v3 = val[3];
        
        
        int16_t p_r = ((v2 & 0xff)| ((v3 << 8) & 0xff00));
        
        int16_t t_r = ((v0 & 0xff)| ((v1 << 8) & 0xff00));
        
        self.ambientTemp = [NSNumber numberWithDouble:calcBarTmp(t_r, _c1, _c2)];
        self.pressure = [NSNumber numberWithDouble:calcBarPress(t_r,
                                                                p_r,
                                                                _c3,
                                                                _c4,
                                                                _c5,
                                                                _c6,
                                                                _c7,
                                                                _c8)];
        
        
    } else if ([yc.name isEqualToString:@"config"]) {
        if (self.isCalibrating) {
            [self readValueForCharacteristicName:@"calibration"];
        }
        
    } else if ([yc.name isEqualToString:@"calibration"]) {
        self.isCalibrating = NO;
        NSData *data = yc.cbCharacteristic.value;
        
        char val[data.length];
        [data getBytes:&val length:data.length];
        
        int i = 0;
        while (i < data.length) {
            uint16_t lo = val[i];
            uint16_t hi = val[i+1];
            uint16_t cx = ((lo & 0xff)| ((hi << 8) & 0xff00));
            int index = i/2 + 1;

            if (index == 1) self.c1 = cx;
            else if (index == 2) self.c2 = cx;
            else if (index == 3) self.c3 = cx;
            else if (index == 4) self.c4 = cx;
            else if (index == 5) self.c5 = cx;
            else if (index == 6) self.c6 = cx;
            else if (index == 7) self.c7 = cx;
            else if (index == 8) self.c8 = cx;
            
            i = i + 2;
        }

        self.isCalibrated = YES;
    }
}


@end
