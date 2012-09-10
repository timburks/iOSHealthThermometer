//
//  ThermometerViewController.m
//  iOSHealthThermometer
//
//  Created by Tim Burks on 7/2/12.
//  Copyright (c) 2012 Radtastical Inc. All rights reserved.
//

#import "ThermometerViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>


#define CAMERA_ENABLED

#ifdef CAMERA_ENABLED
#import "CameraView.h"
#endif

@interface ThermometerViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *temperatureCharacteristic;
@property (nonatomic, strong) CBCharacteristic *intermediateTemperatureCharacteristic;
@property (nonatomic, strong) NSMutableArray *thermometers;

@property (nonatomic, strong) UILabel *temperatureLabel;
@property (nonatomic, strong) UILabel *rssiLabel;
@property (nonatomic, strong) UILabel *manufacturerLabel;

@property (nonatomic, assign) BOOL automaticallyReconnect;
#ifdef CAMERA_ENABLED
@property (nonatomic, strong) CameraView *cameraView;
#endif
@end

@implementation ThermometerViewController

- (id) init {
    if (self = [super init]) {
        self.thermometers = [NSMutableArray array];
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        [self startScan];
    }
    return self;
}

- (void) prepareLabel:(UILabel *) label {
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleHeight;
    label.textAlignment = UITextAlignmentCenter;
    label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    label.textColor = [UIColor whiteColor];
    [self.view addSubview:label];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    
    UIImageView *imageView = [[UIImageView alloc]
                              initWithImage:[UIImage imageNamed:@"BLE112_eval_kit_web_pic.png"]];
    [self.view addSubview:imageView];
    CGRect imageFrame = imageView.frame;
    imageFrame.origin.x = 0.5*(self.view.bounds.size.width - imageFrame.size.width);
    imageFrame.origin.y = 0.5*(self.view.bounds.size.height - imageFrame.size.height);
    imageView.frame = imageFrame;
    

#ifdef CAMERA_ENABLED
    self.cameraView = [[CameraView alloc] initWithFrame:self.view.bounds];
    self.cameraView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.cameraView];
#endif
    
    CGRect labelFrame = self.view.bounds;
    labelFrame.size.height = self.view.bounds.size.height * 0.15;
    self.temperatureLabel = [[UILabel alloc] initWithFrame:labelFrame];
    self.temperatureLabel.font = [UIFont boldSystemFontOfSize:self.view.bounds.size.height * 0.1];
    self.temperatureLabel.text = @"--";
    [self prepareLabel:self.temperatureLabel];
    
    self.rssiLabel = [[UILabel alloc]
                      initWithFrame:CGRectOffset(self.temperatureLabel.frame,
                                                 0,
                                                 self.temperatureLabel.frame.size.height)];
    self.rssiLabel.font = [UIFont boldSystemFontOfSize:self.view.bounds.size.height * 0.05];
    self.rssiLabel.text = @"--";
    [self prepareLabel:self.rssiLabel];
    
    
    labelFrame = self.view.bounds;
    labelFrame.size.height = self.view.bounds.size.height * 0.1;
    labelFrame.origin.y = self.view.bounds.size.height - labelFrame.size.height;
    self.manufacturerLabel = [[UILabel alloc] initWithFrame:labelFrame];
    self.manufacturerLabel.font = [UIFont boldSystemFontOfSize:self.view.bounds.size.height * 0.05];
    self.manufacturerLabel.text = @"Disconnected";
    [self prepareLabel:self.manufacturerLabel];
}

- (void) viewWillAppear:(BOOL)animated {
#ifdef CAMERA_ENABLED
    [self.cameraView startUpdating];
#endif
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Start/Stop Scan methods

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    switch ([self.manager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    NSLog(@"Central manager state: %@", state);
    return FALSE;
}

// Request CBCentralManager to scan for peripherals
- (void) startScan
{
    NSLog(@"startScan");
    self.automaticallyReconnect = YES;
    NSArray *services = [NSArray arrayWithObject:[CBUUID UUIDWithString:@"F5E33626-FBD9-5263-98AA-1E0D2FCE4C65"]]; // nil; // [NSArray arrayWithObject:[CBUUID UUIDWithString:@"1809"]];
    [self.manager scanForPeripheralsWithServices:nil options:nil];
}

// Request CBCentralManager to stop scanning for peripherals
- (void) stopScan
{
    [self.manager stopScan];
}

- (void) disconnect
{
    self.automaticallyReconnect = NO;
    if (self.peripheral) {
        [self.manager retrieveConnectedPeripherals];
    }
}

- (void) centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    for (CBPeripheral *peripheral in peripherals) {
        NSLog(@"canceling connection to %@", peripheral);
        [self.manager cancelPeripheralConnection:peripheral];
    }
}


#pragma mark - CBCentralManager delegate methods

// Invoked when the central manager's state is updated.
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
}


- (void) connectToPeripheral:(CBPeripheral *) peripheral {
    [self stopScan];
    self.peripheral = peripheral;
    [self.peripheral setDelegate:self];
    NSLog(@"connecting...");
    [self.manager connectPeripheral:peripheral
                            options:[NSDictionary dictionaryWithObject:
                                     [NSNumber numberWithBool:YES]
                                                                forKey:
                                     CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}


// Invoked when the central discovers peripheral while scanning.
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"RSSI %@", RSSI);
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"thermometers"];
    if(![self.thermometers containsObject:peripheral])
        [peripherals addObject:peripheral];
    
    [self connectToPeripheral:peripheral];
    // Retrieve already known devices
  //  [self.manager retrievePeripherals:[NSArray arrayWithObject:(id)peripheral.UUID]];
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %u - %@", [peripherals count], peripherals);
}

// Invoked when a connection is succesfully created with the peripheral.
// Discover available services on the peripheral
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"connected");
    [peripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void) centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{
    NSLog(@"centralManager:%@ didDisconnectPeripheral:%@ error:%@", central, peripheral, error);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
    self.temperatureLabel.text = @"--";
    self.rssiLabel.text = @"--";
    self.manufacturerLabel.text = @"Disconnected";
    if (self.automaticallyReconnect) {
        [self startScan];
    }
}

// Invoked when the central manager fails to create a connection with the peripheral.
- (void) centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", peripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in peripheral.services) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Thermometer Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"1809"]]) {
            [peripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* Device Information Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]) {
            [peripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* GAP (Generic Access Profile) for Device Name */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]]) {
            [peripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"peripheral:didDiscoverCharacteristicsForService:%@", service.UUID.data);

    if (error)
    {
        NSLog(@"Discovered characteristics for %@ with error: %@",
              service.UUID, [error localizedDescription]);
        return;
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:@"1809"]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            NSLog(@"discovered characteristic %@", characteristic.UUID);
            /* Set indication on temperature measurement */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1C"]])
            {
                self.temperatureCharacteristic = characteristic;
                [self.peripheral setNotifyValue:YES forCharacteristic:self.temperatureCharacteristic];
                NSLog(@"Found a Temperature Measurement Characteristic");
            }
            /* Set notification on intermediate temperature measurement */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1E"]])
            {
                self.intermediateTemperatureCharacteristic = characteristic;
                NSLog(@"Found an Intermediate Temperature Measurement Characteristic");
                [self.peripheral setNotifyValue:YES forCharacteristic:self.intermediateTemperatureCharacteristic];
            }
            /* Write value to measurement interval characteristic */
            if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A24"]])
            {
                uint16_t val = 2;
                NSData * valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
                [self.peripheral writeValue:valData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                NSLog(@"Found a Temperature Measurement Interval Characteristic - Write interval value");
            }
        }
    }
    
    else if([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            NSLog(@"discovered 180A characteristic %@", characteristic.UUID);
            /* Read manufacturer name */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
            {
                [self.peripheral readValueForCharacteristic:characteristic];
                NSLog(@"Found a Device Manufacturer Name Characteristic - Read manufacturer name");
            }
            else {
                [self.peripheral readValueForCharacteristic:characteristic];
                
            }
        }
    }
    
    else if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *characteristic in service.characteristics)
        {
            NSLog(@"discovered generic characteristic %@", characteristic.UUID);
            
            /* Read device name */
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
              //  [self.peripheral readValueForCharacteristic:characteristic];
              //  NSLog(@"Found a Device Name Characteristic - Read device name");
            }
        }
    }
    
    else {
        NSLog(@"unknown service discovery %@", service.UUID);
        
    }
}

/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void) peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    /* Updated value for temperature measurement received */
    if(([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1E"]] ||
        [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A1C"]]) &&
       characteristic.value)
    {
        NSData * updatedValue = characteristic.value;
        uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
        
        uint8_t flags = dataPointer[0]; dataPointer++;
        int32_t tempData = (int32_t)CFSwapInt32LittleToHost(*(uint32_t*)dataPointer); dataPointer += 4;
        int8_t exponent = (int8_t)(tempData >> 24);
        int32_t mantissa = (int32_t)(tempData & 0x00FFFFFF);
        
        if( tempData == 0x007FFFFF )
        {
            NSLog(@"Invalid temperature value received");
            return;
        }
        
        float tempValue = (float)(mantissa*pow(10, exponent));
        NSString *temperatureString = [NSString stringWithFormat:@"%.1f", tempValue];
        NSLog(@"temperatureString %@", temperatureString);
        
        /* measurement type */
        if(flags & 0x01)
        {
            temperatureString = [temperatureString stringByAppendingString:@"ºF"];
            NSLog(@"measurement type: ºF");
        }
        else
        {
            temperatureString = [temperatureString stringByAppendingString:@"ºC"];
            NSLog(@"measurement type: ºC");
        }
        
        /* timestamp */
        if( flags & 0x02 )
        {
            uint16_t year = CFSwapInt16LittleToHost(*(uint16_t*)dataPointer); dataPointer += 2;
            uint8_t month = *(uint8_t*)dataPointer; dataPointer++;
            uint8_t day = *(uint8_t*)dataPointer; dataPointer++;
            uint8_t hour = *(uint8_t*)dataPointer; dataPointer++;
            uint8_t min = *(uint8_t*)dataPointer; dataPointer++;
            uint8_t sec = *(uint8_t*)dataPointer; dataPointer++;
            
            NSString * dateString = [NSString stringWithFormat:@"%d %d %d %d %d %d", year, month, day, hour, min, sec];
            
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat: @"yyyy MM dd HH mm ss"];
            NSDate* date = [dateFormat dateFromString:dateString];
            
            [dateFormat setDateFormat:@"EEE MMM dd, yyyy"];
            NSString* dateFormattedString = [dateFormat stringFromDate:date];
            
            [dateFormat setDateFormat:@"h:mm a"];
            NSString* timeFormattedString = [dateFormat stringFromDate:date];
            
            
            if( dateFormattedString && timeFormattedString )
            {
                NSString *timeStampString = [NSString stringWithFormat:@"%@ at %@", dateFormattedString, timeFormattedString];
                NSLog(@"timestamp %@", timeStampString);
            }
        }
        
        /* temperature type */
        if( flags & 0x04 )
        {
            uint8_t type = *(uint8_t*)dataPointer;
            NSString* location = nil;
            
            switch (type)
            {
                case 0x01:
                    location = @"Armpit";
                    break;
                case 0x02:
                    location = @"Body - general";
                    break;
                case 0x03:
                    location = @"Ear";
                    break;
                case 0x04:
                    location = @"Finger";
                    break;
                case 0x05:
                    location = @"Gastro-intenstinal Tract";
                    break;
                case 0x06:
                    location = @"Mouth";
                    break;
                case 0x07:
                    location = @"Rectum";
                    break;
                case 0x08:
                    location = @"Toe";
                    break;
                case 0x09:
                    location = @"Tympanum - ear drum";
                    break;
                default:
                    break;
            }
            if (location)
            {
                NSString *temperatureType = [NSString stringWithFormat:@"Body location: %@", location];
                NSLog(@"temp type: %@", temperatureType);
            }
        }
        
        [self.peripheral readRSSI];
        
        self.temperatureLabel.text = temperatureString;
        self.rssiLabel.text = [self.peripheral.RSSI stringValue];
    }
    
    /* Value for device name received */
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
    {
        NSString *deviceName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"Device Name = %@", deviceName);
    }
    
    /* Value for manufacturer name received */
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
    {
        NSString *manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"Manufacturer Name = %@", manufacturerName);
        self.manufacturerLabel.text = manufacturerName;
    }
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A24"]])
    {
        NSLog(@"2A24 thing happening");
        NSString *thing = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"thing = %@", thing);
    }
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A25"]])
    {
        NSLog(@"2A25 thing happening");
        NSData * updatedValue = characteristic.value;
        NSLog(@"length %d", [updatedValue length]);
    }
    else {
        NSLog(@"unknown thing happening");
        NSString *thing = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"thing = %@", thing);
    }
}

@end
