import 'package:flutter/material.dart';
import 'package:wallet_flutter/model/setting_item.dart';

enum CurrencyModeOptions { NANO, NYANO, BANANO }

/// Represent nyano/nano  setting
class CurrencyModeSetting extends SettingSelectionItem {
  CurrencyModeOptions? setting;

  CurrencyModeSetting(this.setting);

  String getDisplayName([BuildContext? context]) {
    switch (setting) {
      case CurrencyModeOptions.NANO:
        return "NANO";
      case CurrencyModeOptions.NYANO:
        return "NYANO";
      case CurrencyModeOptions.BANANO:
        return "BANANO";
      default:
        return "NANO";
    }
  }

  // For saving to shared prefs
  int getIndex() {
    return setting!.index;
  }
}
