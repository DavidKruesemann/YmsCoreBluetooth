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

#include "TISensorTag.h"
#import "YMSCBAppService.h"
#import "YMSCBPeripheral.h"
#import "YMSCBService.h"
#import "YMSCBCharacteristic.h"


@implementation YMSCBAppService

- (id)initWithKnownPeripheralNames:(NSArray *)nameList queue:(dispatch_queue_t)queue {
    self = [super init];
    
    if (self) {
        _ymsPeripherals = [[NSMutableArray alloc] init];
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
        _currentManagerState = -1;
        _knownPeripheralNames = nameList;
    }
    
    return self;
}



- (void)persistPeripherals {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *devices = [[NSMutableArray alloc] init];
    
    for (YMSCBPeripheral *sensorTag in self.ymsPeripherals) {
        CBPeripheral *p = sensorTag.cbPeripheral;
        CFStringRef uuidString = NULL;
        
        uuidString = CFUUIDCreateString(NULL, p.UUID);
        if (uuidString) {
            [devices addObject:(NSString *)CFBridgingRelease(uuidString)];
        }
        
    }
    
    [userDefaults setObject:devices forKey:@"storedPeripherals"];
    [userDefaults synchronize];
}


- (void)loadPeripherals {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *devices = [userDefaults arrayForKey:@"storedPeripherals"];
    NSMutableArray *peripheralUUIDList = [[NSMutableArray alloc] init];
    
    if (![devices isKindOfClass:[NSArray class]]) {
        // TODO - need right error handler
        NSLog(@"No stored array to load");
    }
    
    for (id uuidString in devices) {
        if (![uuidString isKindOfClass:[NSString class]]) {
            continue;
        }
        
        CFUUIDRef uuid = CFUUIDCreateFromString(NULL, (CFStringRef)uuidString);
        
        if (!uuid)
            continue;
        
        [peripheralUUIDList addObject:(id)CFBridgingRelease(uuid)];
    }
    
    if ([peripheralUUIDList count] > 0) {
        [self.manager retrievePeripherals:peripheralUUIDList];
    }
}

- (YMSCBPeripheral *)peripheralAtIndex:(NSUInteger)index {
    YMSCBPeripheral *result;
    result = (YMSCBPeripheral *)[self.ymsPeripherals objectAtIndex:index];
    return result;
}

- (NSUInteger)count {
    return  [self.ymsPeripherals count];
}

- (void)addPeripheral:(YMSCBPeripheral *)yperipheral {
    [self.ymsPeripherals addObject:yperipheral];
}

- (void)removePeripheral:(YMSCBPeripheral *)yperipheral {
    
    if (yperipheral.cbPeripheral.UUID != nil) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSArray *devices = [userDefaults arrayForKey:@"storedPeripherals"];
        NSMutableArray *newDevices = [NSMutableArray arrayWithArray:devices];
    
        NSString *uuidString = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, yperipheral.cbPeripheral.UUID));
        
        [newDevices removeObject:uuidString];
        
        [userDefaults setObject:newDevices forKey:@"storedPeripherals"];
        [userDefaults synchronize];
    }
    
    
    [self.ymsPeripherals removeObject:yperipheral];
}

- (void)removePeripheralAtIndex:(NSUInteger)index {
    
    YMSCBPeripheral *yperipheral = [self.ymsPeripherals objectAtIndex:index];
    
    [self removePeripheral:yperipheral];
}

- (BOOL)isKnownPeripheral:(CBPeripheral *)peripheral {
    BOOL result = NO;
    
    for (NSString *key in self.knownPeripheralNames) {
        result = result || [peripheral.name isEqualToString:key];
        if (result) {
            break;
        }
    }
    
    return result;
}


- (void)startScan {
    /*
     * THIS METHOD IS TO BE OVERRIDDEN
     */
    
    NSAssert(NO, @"[YMSCBAppService startScan] must be be overridden and include call to [self scanForPeripherals:options:]");
    
    //[self scanForPeripheralsWithServices:nil options:nil];
}


- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs options:(NSDictionary *)options {
    [self.manager scanForPeripheralsWithServices:serviceUUIDs options:options];
    self.isScanning = YES;
}


- (void)stopScan {
    [self.manager stopScan];
    self.isScanning = NO;
}


- (YMSCBPeripheral *)findPeripheral:(CBPeripheral *)peripheral {
    
    YMSCBPeripheral *result = nil;
    
    for (YMSCBPeripheral *yPeripheral in self.ymsPeripherals) {
        if (yPeripheral.cbPeripheral == peripheral) {
            result = yPeripheral;
            break;
        }
    }
    
    return result;
}



- (void)handleFoundPeripheral:(CBPeripheral *)peripheral {
    /*
     * THIS METHOD IS TO BE OVERRIDDEN
     */
    
    NSAssert(NO, @"[YMSCBAppService handleFoundPeripheral:] must be be overridden.");

}


- (void)connectPeripheral:(NSUInteger)index {
    if ([self.ymsPeripherals count] > 0) {
        YMSCBPeripheral *yPeripheral = self.ymsPeripherals[index];
        [self.manager connectPeripheral:yPeripheral.cbPeripheral options:nil];
    }

}

- (void)disconnectPeripheral:(NSUInteger)index {
    if ([self.ymsPeripherals count] > 0) {
        YMSCBPeripheral *yPeripheral = self.ymsPeripherals[index];
        [self.manager cancelPeripheralConnection:yPeripheral.cbPeripheral];
    }
}


#pragma mark CBCentralManagerDelegate Protocol Methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {

    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self loadPeripherals];
            break;
            
        case CBCentralManagerStateUnknown:
            break;
            
        case CBCentralManagerStatePoweredOff:
            if (_currentManagerState != -1) {
            }
            break;
            
        case CBCentralManagerStateResetting:
            break;
            
        case CBCentralManagerStateUnauthorized:
            break;
            
        case CBCentralManagerStateUnsupported: {
            break;
        }
    }
    
    _currentManagerState = central.state;
    
    if ([self.delegate respondsToSelector:@selector(centralManagerDidUpdateState:)]) {
        [self.delegate centralManagerDidUpdateState:central];
    }

}


- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    
    NSLog(@"%@, %@, %@ db", peripheral, peripheral.name, RSSI);
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *existingDevices = [userDefaults objectForKey:@"storedPeripherals"];
    NSMutableArray *devices;
    NSString *uuidString = nil;
    if (peripheral.UUID != nil) {
        uuidString = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, peripheral.UUID));
        
        if (existingDevices != nil) {
            devices = [[NSMutableArray alloc] initWithArray:existingDevices];
            
            if (uuidString) {
                BOOL test = YES;
                
                for (NSString *obj in existingDevices) {
                    if ([obj isEqualToString:uuidString]) {
                        test = NO;
                        break;
                    }
                }
                
                if (test) {
                    [devices addObject:uuidString];
                }
            }
        }
        else {
            devices = [[NSMutableArray alloc] init];
            [devices addObject:uuidString];
            
        }
        
        [userDefaults setObject:devices forKey:@"storedPeripherals"];
        [userDefaults synchronize];
    }

    [self handleFoundPeripheral:peripheral];

    if ([self.delegate respondsToSelector:@selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)]) {
        [self.delegate centralManager:central didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
    }

}



- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {

    for (CBPeripheral *peripheral in peripherals) {
        [self handleFoundPeripheral:peripheral];
    }
    
    if ([self.delegate respondsToSelector:@selector(centralManager:didRetrievePeripherals:)]) {
        [self.delegate centralManager:central didRetrievePeripherals:peripherals];
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
    
    for (CBPeripheral *peripheral in peripherals) {
        [self handleFoundPeripheral:peripheral];
    }

    if ([self.delegate respondsToSelector:@selector(centralManager:didRetrieveConnectedPeripherals:)]) {
        [self.delegate centralManager:central didRetrieveConnectedPeripherals:peripherals];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if ([self isKnownPeripheral:peripheral]) {
        YMSCBPeripheral *yp = [self findPeripheral:peripheral];
        
        if (yp != nil) {
            NSArray *services = [yp services];
            [peripheral discoverServices:services];
            
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(centralManager:didConnectPeripheral:)]) {
        [self.delegate centralManager:central didConnectPeripheral:peripheral];
    }
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    YMSCBPeripheral *yp = [self findPeripheral:peripheral];
    
    for (id key in yp.serviceDict) {
        YMSCBService *service = yp.serviceDict[key];
        service.cbService = nil;
        service.isOn = NO;
        service.isEnabled = NO;
    }
    
    
    if ([self.delegate respondsToSelector:@selector(centralManager:didDisconnectPeripheral:error:)]) {
        [self.delegate centralManager:central didDisconnectPeripheral:peripheral error:error];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(centralManager:didFailToConnectPeripheral:error:)]) {
        [self.delegate centralManager:central didFailToConnectPeripheral:peripheral error:error];
    }
    
}



@end
