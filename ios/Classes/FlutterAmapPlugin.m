#import "FlutterAmapPlugin.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>

@interface FlutterAmapPlugin()<AMapLocationManagerDelegate>

@end

@implementation FlutterAmapPlugin {
  AMapLocationManager *locationManager;
  AMapLocatingCompletionBlock completionBlock;
  FlutterMethodChannel* channel;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"chavesgu/flutter_amap"
            binaryMessenger:[registrar messenger]];
  FlutterAmapPlugin* instance = [[FlutterAmapPlugin alloc] initWithAMapPlugin:channel];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithAMapPlugin:(FlutterMethodChannel*)_channel{
    self = [super init];
    channel= _channel;
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  ((void (^)(void))@{
    @"setKey": ^{
      [[AMapServices sharedServices] setEnableHTTPS:YES];
      [AMapServices sharedServices].apiKey = call.arguments;
      result(@YES);
    },
    @"init": ^{
      result(@([self init:call.arguments]));
    },
    @"dispose": ^{
      result(@([self dispose]));
    },
    @"getLocation": ^{
      // 单次定位
      [self getLocation: [call.arguments boolValue] result:result];
    },
    @"startLocation": ^{
      // 开始监听位置
      if(self->locationManager){
        [self->locationManager startUpdatingLocation];
        result(@YES);
        return;
      }
      result(@NO);
    },
    @"stopLocation": ^{
      // 停止监听位置
      if(self->locationManager){
        [self->locationManager stopUpdatingLocation];
        result(@YES);
        return;
      }
      result(@NO);
    },
    @"getPlatformVersion": ^{
      result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    },
  }[call.method] ?: ^{
    result(FlutterMethodNotImplemented);
  })();
}

// 初始化定位参数
-(BOOL)init:(NSDictionary*)args{
    if(!locationManager){
      locationManager = [[AMapLocationManager alloc] init];
      [locationManager setDelegate:self];
    }
    return [self initOption:args];
}

// 初始化定位参数
-(BOOL)initOption:(NSDictionary*)args{
    if(locationManager){
        //设置期望定位精度
        [locationManager setDesiredAccuracy:[ self getDesiredAccuracy: args[@"desiredAccuracy"]]];
        [locationManager setPausesLocationUpdatesAutomatically:[args[@"pausesLocationUpdatesAutomatically"] boolValue]];
        [locationManager setDistanceFilter: [args[@"distanceFilter"] doubleValue]];
        //设置在能不能再后台定位
        [locationManager setAllowsBackgroundLocationUpdates:[args[@"allowsBackgroundLocationUpdates"] boolValue]];
        //设置定位超时时间
        [locationManager setLocationTimeout:[args[@"locationTimeout"] integerValue]];
        //设置逆地理超时时间
        [locationManager setReGeocodeTimeout:[args[@"reGeocodeTimeout"] integerValue]];
        //定位是否需要逆地理信息
        [locationManager setLocatingWithReGeocode:[args[@"locatingWithReGeocode"] boolValue]];
        ///检测是否存在虚拟定位风险，默认为NO，不检测。 \n注意:设置为YES时，单次定位通过 AMapLocatingCompletionBlock 的error给出虚拟定位风险提示；连续定位通过 amapLocationManager:didFailWithError: 方法的error给出虚拟定位风险提示。error格式为error.domain==AMapLocationErrorDomain; error.code==AMapLocationErrorRiskOfFakeLocation;
        [locationManager setDetectRiskOfFakeLocation: [args[@"detectRiskOfFakeLocation"] boolValue ]];
        return YES;
    }
    return NO;
}

-(double)getDesiredAccuracy:(NSString*)str{
    if([@"kCLLocationAccuracyBest" isEqualToString:str]){
        return kCLLocationAccuracyBest;
    }else if([@"kCLLocationAccuracyNearestTenMeters" isEqualToString:str]){
        return kCLLocationAccuracyNearestTenMeters;
    }else if([@"kCLLocationAccuracyHundredMeters" isEqualToString:str]){
        return kCLLocationAccuracyHundredMeters;
    }else if([@"kCLLocationAccuracyKilometer" isEqualToString:str]){
        return kCLLocationAccuracyKilometer;
    }else{
        return kCLLocationAccuracyThreeKilometers;
    }
}

-(void)getLocation:(BOOL)withReGeocode result:(FlutterResult)result{
    completionBlock = ^(CLLocation *location, AMapLocationReGeocode *reGeocode, NSError *error){
        if (error != nil && error.code == AMapLocationErrorLocateFailed) {
            //定位错误：此时location和reGeocode没有返回值，不进行annotation的添加
            //            NSLog(@"定位错误:{%ld - %@};", (long)error.code, error.localizedDescription);
            result(@{ @"code":@(error.code),@"description":error.localizedDescription, @"success":@NO });
            return;
        }  else if (error != nil
                    && (error.code == AMapLocationErrorReGeocodeFailed
                        || error.code == AMapLocationErrorTimeOut
                        || error.code == AMapLocationErrorCannotFindHost
                        || error.code == AMapLocationErrorBadURL
                        || error.code == AMapLocationErrorNotConnectedToInternet
                        || error.code == AMapLocationErrorCannotConnectToHost)) {
            //逆地理错误：在带逆地理的单次定位中，逆地理过程可能发生错误，此时location有返回值，reGeocode无返回值，进行annotation的添加
            //            NSLog(@"逆地理错误:{%ld - %@};", (long)error.code, error.localizedDescription);
          result(@{ @"code":@(error.code),@"description":error.localizedDescription, @"success":@NO });
        } else if (error != nil && error.code == AMapLocationErrorRiskOfFakeLocation) {
            //存在虚拟定位的风险：此时location和reGeocode没有返回值，不进行annotation的添加
            //            NSLog(@"存在虚拟定位的风险:{%ld - %@};", (long)error.code, error.localizedDescription);
            result(@{ @"code":@(error.code),@"description":error.localizedDescription, @"success":@NO  });
            return;
        } else {
            //没有错误：location有返回值，reGeocode是否有返回值取决于是否进行逆地理操作，进行annotation的添加
            NSMutableDictionary* md = [[NSMutableDictionary alloc]initWithDictionary: [self location2map:location]  ];
            if (reGeocode) {
                [md addEntriesFromDictionary:[self reGeocode2map:reGeocode]];
                md[@"code"] = @0;
                md[@"success"] = @YES;
            } else{
                md[@"code"]=@(error.code);
                md[@"description"]=error.localizedDescription;
                md[@"success"] = @YES;
            }
            result(md);
        }
    };
    [locationManager requestLocationWithReGeocode:withReGeocode completionBlock:completionBlock];
}

-(BOOL)dispose{
    if(locationManager){
        //停止定位
        [locationManager stopUpdatingLocation];
        [locationManager setDelegate:nil];
        locationManager = nil;
        return YES;
    }
    return NO;
}

-(id)checkNull:(NSObject*)value{
    return value == nil ? [NSNull null] : value;
}

-(NSDictionary*)location2map:(CLLocation *)location{
    return @{@"latitude": @(location.coordinate.latitude),
             @"longitude": @(location.coordinate.longitude),
             @"accuracy": @((location.horizontalAccuracy + location.verticalAccuracy)/2),
             @"altitude": @(location.altitude),
             @"speed": @(location.speed),
             @"timestamp": @(location.timestamp.timeIntervalSince1970),};
}

-(NSDictionary*)reGeocode2map:(AMapLocationReGeocode *)reGeocode{
    return @{@"formattedAddress":reGeocode.formattedAddress,
             @"country":reGeocode.country,
             @"province":reGeocode.province,
             @"city":reGeocode.city,
             @"district":reGeocode.district,
             @"cityCode":reGeocode.citycode,
             @"adCode":reGeocode.adcode,
             @"street":reGeocode.street,
             @"number":reGeocode.number,
             @"poiName":[self checkNull : reGeocode.POIName],
             @"aoiName":[self checkNull :reGeocode.AOIName],
    };
}

/**
 *  @brief 连续定位回调函数.注意：如果实现了本方法，则定位信息不会通过amapLocationManager:didUpdateLocation:方法回调。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param location 定位结果。
 *  @param reGeocode 逆地理信息。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode{
    NSMutableDictionary* md = [[NSMutableDictionary alloc]initWithDictionary: [self location2map:location]];
    if(reGeocode) [md addEntriesFromDictionary:[self reGeocode2map:reGeocode ]];
    
    md[@"success"]=@YES;
    [channel invokeMethod:@"updateLocation" arguments:md];
}

/**
 *  @brief 定位权限状态改变时回调函数
 *  @param manager 定位 AMapLocationManager 类。
 *  @param status 定位权限状态。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
}

/**
 *  @brief 当定位发生错误时，会调用代理的此方法。
 *  @param manager 定位 AMapLocationManager 类。
 *  @param error 返回的错误，参考 CLError 。
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error{
    [channel invokeMethod:@"updateLocation" arguments:@{ @"code":@(error.code),@"description":error.localizedDescription,@"success":@NO }];
    
}

@end
