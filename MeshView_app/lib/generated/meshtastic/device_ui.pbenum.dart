//
//  Generated code. Do not modify.
//  source: meshtastic/device_ui.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompassMode extends $pb.ProtobufEnum {
  static const CompassMode DYNAMIC = CompassMode._(0, _omitEnumNames ? '' : 'DYNAMIC');
  static const CompassMode FIXED_RING = CompassMode._(1, _omitEnumNames ? '' : 'FIXED_RING');
  static const CompassMode FREEZE_HEADING = CompassMode._(2, _omitEnumNames ? '' : 'FREEZE_HEADING');

  static const $core.List<CompassMode> values = <CompassMode> [
    DYNAMIC,
    FIXED_RING,
    FREEZE_HEADING,
  ];

  static final $core.Map<$core.int, CompassMode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CompassMode? valueOf($core.int value) => _byValue[value];

  const CompassMode._($core.int v, $core.String n) : super(v, n);
}

class Theme extends $pb.ProtobufEnum {
  static const Theme DARK = Theme._(0, _omitEnumNames ? '' : 'DARK');
  static const Theme LIGHT = Theme._(1, _omitEnumNames ? '' : 'LIGHT');
  static const Theme RED = Theme._(2, _omitEnumNames ? '' : 'RED');

  static const $core.List<Theme> values = <Theme> [
    DARK,
    LIGHT,
    RED,
  ];

  static final $core.Map<$core.int, Theme> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Theme? valueOf($core.int value) => _byValue[value];

  const Theme._($core.int v, $core.String n) : super(v, n);
}

///
///  Localization
class Language extends $pb.ProtobufEnum {
  static const Language ENGLISH = Language._(0, _omitEnumNames ? '' : 'ENGLISH');
  static const Language FRENCH = Language._(1, _omitEnumNames ? '' : 'FRENCH');
  static const Language GERMAN = Language._(2, _omitEnumNames ? '' : 'GERMAN');
  static const Language ITALIAN = Language._(3, _omitEnumNames ? '' : 'ITALIAN');
  static const Language PORTUGUESE = Language._(4, _omitEnumNames ? '' : 'PORTUGUESE');
  static const Language SPANISH = Language._(5, _omitEnumNames ? '' : 'SPANISH');
  static const Language SWEDISH = Language._(6, _omitEnumNames ? '' : 'SWEDISH');
  static const Language FINNISH = Language._(7, _omitEnumNames ? '' : 'FINNISH');
  static const Language POLISH = Language._(8, _omitEnumNames ? '' : 'POLISH');
  static const Language TURKISH = Language._(9, _omitEnumNames ? '' : 'TURKISH');
  static const Language SERBIAN = Language._(10, _omitEnumNames ? '' : 'SERBIAN');
  static const Language RUSSIAN = Language._(11, _omitEnumNames ? '' : 'RUSSIAN');
  static const Language DUTCH = Language._(12, _omitEnumNames ? '' : 'DUTCH');
  static const Language GREEK = Language._(13, _omitEnumNames ? '' : 'GREEK');
  static const Language NORWEGIAN = Language._(14, _omitEnumNames ? '' : 'NORWEGIAN');
  static const Language SLOVENIAN = Language._(15, _omitEnumNames ? '' : 'SLOVENIAN');
  static const Language UKRAINIAN = Language._(16, _omitEnumNames ? '' : 'UKRAINIAN');
  static const Language BULGARIAN = Language._(17, _omitEnumNames ? '' : 'BULGARIAN');
  static const Language CZECH = Language._(18, _omitEnumNames ? '' : 'CZECH');
  static const Language DANISH = Language._(19, _omitEnumNames ? '' : 'DANISH');
  static const Language SIMPLIFIED_CHINESE = Language._(30, _omitEnumNames ? '' : 'SIMPLIFIED_CHINESE');
  static const Language TRADITIONAL_CHINESE = Language._(31, _omitEnumNames ? '' : 'TRADITIONAL_CHINESE');

  static const $core.List<Language> values = <Language> [
    ENGLISH,
    FRENCH,
    GERMAN,
    ITALIAN,
    PORTUGUESE,
    SPANISH,
    SWEDISH,
    FINNISH,
    POLISH,
    TURKISH,
    SERBIAN,
    RUSSIAN,
    DUTCH,
    GREEK,
    NORWEGIAN,
    SLOVENIAN,
    UKRAINIAN,
    BULGARIAN,
    CZECH,
    DANISH,
    SIMPLIFIED_CHINESE,
    TRADITIONAL_CHINESE,
  ];

  static final $core.Map<$core.int, Language> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Language? valueOf($core.int value) => _byValue[value];

  const Language._($core.int v, $core.String n) : super(v, n);
}

///
///  How the GPS coordinates are displayed on the OLED screen.
class DeviceUIConfig_GpsCoordinateFormat extends $pb.ProtobufEnum {
  static const DeviceUIConfig_GpsCoordinateFormat DEC = DeviceUIConfig_GpsCoordinateFormat._(0, _omitEnumNames ? '' : 'DEC');
  static const DeviceUIConfig_GpsCoordinateFormat DMS = DeviceUIConfig_GpsCoordinateFormat._(1, _omitEnumNames ? '' : 'DMS');
  static const DeviceUIConfig_GpsCoordinateFormat UTM = DeviceUIConfig_GpsCoordinateFormat._(2, _omitEnumNames ? '' : 'UTM');
  static const DeviceUIConfig_GpsCoordinateFormat MGRS = DeviceUIConfig_GpsCoordinateFormat._(3, _omitEnumNames ? '' : 'MGRS');
  static const DeviceUIConfig_GpsCoordinateFormat OLC = DeviceUIConfig_GpsCoordinateFormat._(4, _omitEnumNames ? '' : 'OLC');
  static const DeviceUIConfig_GpsCoordinateFormat OSGR = DeviceUIConfig_GpsCoordinateFormat._(5, _omitEnumNames ? '' : 'OSGR');
  static const DeviceUIConfig_GpsCoordinateFormat MLS = DeviceUIConfig_GpsCoordinateFormat._(6, _omitEnumNames ? '' : 'MLS');

  static const $core.List<DeviceUIConfig_GpsCoordinateFormat> values = <DeviceUIConfig_GpsCoordinateFormat> [
    DEC,
    DMS,
    UTM,
    MGRS,
    OLC,
    OSGR,
    MLS,
  ];

  static final $core.Map<$core.int, DeviceUIConfig_GpsCoordinateFormat> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DeviceUIConfig_GpsCoordinateFormat? valueOf($core.int value) => _byValue[value];

  const DeviceUIConfig_GpsCoordinateFormat._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
