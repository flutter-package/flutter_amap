# flutter_amap

This is a fork of [fl_amap](https://github.com/Wayaer/fl_amap).

## Getting Started

高德地图定位flutter组件。

目前实现获取定位和监听定位功能。


1、申请一个key
http://lbs.amap.com/api/ios-sdk/guide/create-project/get-key

直接在dart文件中设置key

# yaml
```yaml
flutter_amap:
  git:
    url: https://github.com/flutter-package/flutter_amap.git
    ref: master
```

# ios
2、在info.plist中增加:
```
<key>NSLocationWhenInUseUsageDescription</key>
<string>要用定位</string>
```
```
<key>NSLocationAlwaysUsageDescription</key>
<string>要用定位</string>
```
要在iOS 9及以上版本使用后台定位功能, 需要保证"Background Modes"中的"Location updates"处于选中状态


## 开始使用

1.设置key
```dart
await Amap.setKey(
  iosKey: '',
  androidKey: '',
);
```

2.初始化定位参数
```dart
@override
void initState() {
  super.initState();
  Amap.init(AMapLocationOption());
}
```

3.单次获取定位
```dart
AMapLocation? position = await Amap.getLocation();
```

4.开启定位变化监听
```dart
Amap.startLocation((AMapLocation location) {
  //
});
```
5.关闭定位变化监听
```dart
Amap.stopLocation();
```

6.关闭定位系统

```dart
@override
void dispose() {
    super.dispose();
    Amap.dispose();
}
```

### proguard-rules
```
-keep class com.amap.api.location.**{*;}
-keep class com.amap.api.fence.**{*;}
-keep class com.loc.**{*;}
-keep class com.autonavi.aps.amapapi.model.**{*;}
```