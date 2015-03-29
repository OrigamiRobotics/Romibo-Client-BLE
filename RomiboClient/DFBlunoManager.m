//
//  DFBlunoManager.m
//
//  Created by Seifer on 13-12-1.
//  Copyright (c) 2013年 DFRobot. All rights reserved.
//

#import "DFBlunoManager.h"
#import <mach/mach.h>
#import <mach/mach_time.h>

#define kBlunoService @"dfb0"
#define kBlunoDataCharacteristic @"dfb1"

@interface DFBlunoManager ()
{
    BOOL _bSupported;
    uint64_t lastWriteTime;
    BOOL writeInProgress;
    NSData *queuedWrite;
    
}

@property (strong,nonatomic) CBCentralManager* centralManager;
@property (strong,nonatomic) NSMutableDictionary* dicBleDevices;
@property (strong,nonatomic) NSMutableDictionary* dicBlunoDevices;
@property (nonatomic) dispatch_queue_t centralQueue;

@end

@implementation DFBlunoManager

#pragma mark- Functions

+ (id)sharedInstance
{
	static DFBlunoManager* this	= nil;
     NSLog(@" dm instance");
	if (!this)
    {
		this = [[DFBlunoManager alloc] init];
        this.dicBleDevices = [[NSMutableDictionary alloc] init];
        this.dicBlunoDevices = [[NSMutableDictionary alloc] init];
        this->_bSupported = NO;
        this.centralQueue = dispatch_queue_create("centralQueue", DISPATCH_QUEUE_SERIAL);
        this.centralManager = [[CBCentralManager alloc]initWithDelegate:this queue:this.centralQueue];
        this->writeInProgress = NO;
        this->lastWriteTime = 0;
        this->queuedWrite = nil;
    }
    
	return this;
}

- (void)configureSensorTag:(CBPeripheral*)peripheral
{
    
    CBUUID *sUUID = [CBUUID UUIDWithString:kBlunoService];
    CBUUID *cUUID = [CBUUID UUIDWithString:kBlunoDataCharacteristic];
    
    [BLEUtility setNotificationForCharacteristic:peripheral sCBUUID:sUUID cCBUUID:cUUID enable:YES];
    
    NSLog(@"dm configure sensor tag for service");

    NSString* key = [peripheral.identifier UUIDString];
    DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:key];
    blunoDev->_bReadyToWrite = YES;
   
    
    
    if ([((NSObject*)_delegate) respondsToSelector:@selector(readyToCommunicate:)])
    {
        //NSLog(@"dm set rtc");

        [_delegate readyToCommunicate:blunoDev];
    }
    
}

- (void)deConfigureSensorTag:(CBPeripheral*)peripheral
{ NSLog(@" dm deconfig snsr");
    
    CBUUID *sUUID = [CBUUID UUIDWithString:kBlunoService];
    CBUUID *cUUID = [CBUUID UUIDWithString:kBlunoDataCharacteristic];
    
    [BLEUtility setNotificationForCharacteristic:peripheral sCBUUID:sUUID cCBUUID:cUUID enable:NO];
    
}

- (void)scan
{NSLog(@"dm startscan");
    [self.centralManager stopScan];
    //[self.dicBleDevices removeAllObjects];
    //[self.dicBlunoDevices removeAllObjects];
    //if (_bSupported)
    if (1)

        {NSLog(@"dm scanforperiph with service with ID");
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kBlunoService]] options:nil];
           // [self.centralManager scanForPeripheralsWithServices:nil options:nil];

    }

}

- (void)stop
{
    [self.centralManager stopScan];
     NSLog(@" dm stopscan");
}

- (void)clear
{ NSLog(@" dm clear");
    [self.dicBleDevices removeAllObjects];
    [self.dicBlunoDevices removeAllObjects];
}

- (void)connectToDevice:(DFBlunoDevice*)dev
{ NSLog(@" dm connectodev");
    BLEDevice* bleDev = [self.dicBleDevices objectForKey:dev.identifier];
    [bleDev.centralManager connectPeripheral:bleDev.peripheral options:nil];
}

- (void)disconnectToDevice:(DFBlunoDevice*)dev
{ NSLog(@" dm disco");
    BLEDevice* bleDev = [self.dicBleDevices objectForKey:dev.identifier];
    [self deConfigureSensorTag:bleDev.peripheral];
    [bleDev.centralManager cancelPeripheralConnection:bleDev.peripheral];
}

- (void)writeDataToDevice:(NSData*)data Device:(DFBlunoDevice*)dev
{
    //NSLog(@" dm writetodev");
    if (!_bSupported || data == nil)
    {
        return;
    }
    else if(!dev.bReadyToWrite)
    {
        return;
    }
    //writeInProgress = NO;
    if (!writeInProgress)
    {
        BLEDevice* bleDev = [self.dicBleDevices objectForKey:dev.identifier];
        uint64_t nTime = mach_absolute_time();
        NSLog (@"%llu: writing %@", nTime, data.description);
        writeInProgress = YES;
        lastWriteTime = nTime;
        [BLEUtility writeCharacteristic:bleDev.peripheral sUUID:kBlunoService cUUID:kBlunoDataCharacteristic data:data];
    }
    else
    {
        queuedWrite = [data copy];
        
    }
}

#pragma mark - CBCentralManager delegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{    if (central.state != CBCentralManagerStatePoweredOn)
    {
        _bSupported = NO;
        NSArray* aryDeviceKeys = [self.dicBlunoDevices allKeys];
        for (NSString* strKey in aryDeviceKeys)
        { NSLog(@" dm updatestat");
            DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:strKey];
            blunoDev->_bReadyToWrite = NO;
        }
        
    }
    else
    {NSLog(@"dm hi central state =%d",central.state );
        _bSupported = YES;
        
    }
    
    if ([((NSObject*)_delegate) respondsToSelector:@selector(bleDidUpdateState:)])
    {NSLog(@"dm responds to sel ");
        [_delegate bleDidUpdateState:_bSupported];
    }
    
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString* key = [peripheral.identifier UUIDString];
    BLEDevice* dev = [self.dicBleDevices objectForKey:key];
    NSLog(@"dm disco peri %@",key);
    if (dev !=nil )
    {
        //if ([dev.peripheral isEqual:peripheral])
        {
            dev.peripheral = peripheral;
            if ([((NSObject*)_delegate) respondsToSelector:@selector(didDiscoverDevice:)])
            {
                DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:key];
                [_delegate didDiscoverDevice:blunoDev];
            }
        }
    }
    else
    {
        BLEDevice* bleDev = [[BLEDevice alloc] init];
        bleDev.peripheral = peripheral;
        bleDev.centralManager = self.centralManager;
        [self.dicBleDevices setObject:bleDev forKey:key];
        DFBlunoDevice* blunoDev = [[DFBlunoDevice alloc] init];
         NSLog(@" dm did disc peri else");
        blunoDev.identifier = key;
        blunoDev.name = peripheral.name;
        [self.dicBlunoDevices setObject:blunoDev forKey:key];
        NSLog (@"found blunodev %@", blunoDev.name);
        [self stop];
        [self connectToDevice:blunoDev];
        
        if ([((NSObject*)_delegate) respondsToSelector:@selector(didDiscoverDevice:)])
        {
            NSLog (@"notifying delegate object that i found some shiz");
            [_delegate didDiscoverDevice:blunoDev];
        }
    }
}


-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog (@"dm didconnect");
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{ NSLog(@" dm diddisco");
    NSString* key = [peripheral.identifier UUIDString];
    DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:key];
    blunoDev->_bReadyToWrite = NO;
    if ([((NSObject*)_delegate) respondsToSelector:@selector(didDisconnectDevice:)])
    {
        [_delegate didDisconnectDevice:blunoDev];
    }
}

#pragma  mark - CBPeripheral delegate
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{ NSLog(@" dm diddiscsvc");
    for (CBService *s in peripheral.services) [peripheral discoverCharacteristics:nil forService:s];
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:kBlunoService]])
    {NSLog(@" dm diddisccharforsvc");
        [self configureSensorTag:peripheral];
//        NSString* strTemp = @"connecty";
//        NSData* data = [strTemp dataUsingEncoding:NSUTF8StringEncoding];
//        [DFBlunoManager writeDataToDevice:data Device:blunoDev];

       
    }

}


-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if ([((NSObject*)_delegate) respondsToSelector:@selector(didReceiveData:Device:)])
   {//NSLog(@" dm didupdateVal4char");
        NSString* key = [peripheral.identifier UUIDString];
        DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:key];
        [_delegate didReceiveData:characteristic.value Device:blunoDev];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    //NSLog(@"dm i wrote it ");
    uint64_t nTime = mach_absolute_time();
    NSString* key = [peripheral.identifier UUIDString];
    DFBlunoDevice* blunoDev = [self.dicBlunoDevices objectForKey:key];

    NSLog (@"%llu: Wrote.", nTime);
    writeInProgress = NO;
    if (queuedWrite)
    {
        [self writeDataToDevice:queuedWrite Device:blunoDev];
        queuedWrite = nil;
    }
//    if ([((NSObject*)_delegate) respondsToSelector:@selector(didWriteData:)])
    {
        [_delegate didWriteData:blunoDev];
    }
    
}

@end
