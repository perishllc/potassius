import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:nautilus_wallet_flutter/appstate_container.dart';
import 'package:nautilus_wallet_flutter/model/available_currency.dart';
import 'package:nautilus_wallet_flutter/model/db/txdata.dart';
import 'package:nautilus_wallet_flutter/model/db/user.dart';
import 'package:nautilus_wallet_flutter/network/model/response/account_history_response_item.dart';
import 'package:nautilus_wallet_flutter/util/numberutil.dart';

/// Main wallet object that's passed around the app via state
class AppWallet {

  AppWallet(
      {String? address,
      User? user,
      String? username,
      BigInt? accountBalance,
      String? frontier,
      String? openBlock,
      String? representativeBlock,
      String? representative,
      String? localCurrencyPrice,
      String? btcPrice,
      int? blockCount,
      bool watchOnly = false,
      List<AccountHistoryResponseItem>? history,
      List<TXData>? solids,
      bool loading = true,
      bool historyLoading = true,
      this.confirmationHeight = -1}) {
    _address = address;
    _user = user;
    _username = username;
    _accountBalance = accountBalance ?? BigInt.zero;
    _frontier = frontier;
    _openBlock = openBlock;
    _representativeBlock = representativeBlock;
    _representative = representative;
    _localCurrencyPrice = localCurrencyPrice ?? "0";
    _btcPrice = btcPrice ?? "0";
    _blockCount = blockCount ?? 0;
    _history = history ?? [];
    _solids = solids ?? [];
    _unified = unified ?? [];
    _loading = loading;
    _historyLoading = historyLoading;
    _solidsLoading = true;
    _unifiedLoading = true;
    this.watchOnly = watchOnly;
  }
  // the default is randomized but in case the user is offline during account creation we still need a default:
  static String? defaultRepresentative = 'nano_38713x95zyjsqzx6nm1dsom1jmm668owkeb9913ax6nfgj15az3nu8xkx579';
  static String nautilusRepresentative = 'nano_38713x95zyjsqzx6nm1dsom1jmm668owkeb9913ax6nfgj15az3nu8xkx579';

  bool? _loading; // Whether or not app is initially loading
  late bool _historyLoading; // Whether or not we have received initial account history response
  late bool _solidsLoading;
  late bool _unifiedLoading;
  late bool watchOnly;
  String? _address;
  User? _user;
  String? _username;
  late BigInt _accountBalance;
  String? _frontier;
  String? _openBlock;
  String? _representativeBlock;
  String? _representative;
  String? _localCurrencyPrice;
  String? _btcPrice;
  int? _blockCount;
  int confirmationHeight;
  List<AccountHistoryResponseItem>? _history;
  List<TXData>? _solids;
  List<dynamic>? _unified;

  String? get address => _address;

  set address(String? address) {
    _address = address;
  }

  String? get username => _username;

  set username(String? username) {
    _username = username;
  }

  User? get user => _user;

  set user(User? user) {
    _user = user;
  }

  BigInt get accountBalance => _accountBalance;

  set accountBalance(BigInt accountBalance) {
    _accountBalance = accountBalance;
  }

  String getLocalCurrencyBalance(BuildContext context, AvailableCurrency currency, {String? locale = "en_US"}) {
    final BigInt rawPerCur = rawPerNano;
    final Decimal converted = Decimal.parse(_localCurrencyPrice!) * NumberUtil.getRawAsDecimal(_accountBalance.toString(), rawPerCur);
    return NumberFormat.currency(locale: locale, symbol: currency.getCurrencySymbol()).format(converted.toDouble());
  }

  set localCurrencyPrice(String? value) {
    _localCurrencyPrice = value;
  }

  String? get localCurrencyConversion {
    return _localCurrencyPrice;
  }

  String? get representative {
    return _representative ?? defaultRepresentative;
  }

  set representative(String? value) {
    _representative = value;
  }

  String? get representativeBlock => _representativeBlock;

  set representativeBlock(String? value) {
    _representativeBlock = value;
  }

  String? get openBlock => _openBlock;

  set openBlock(String? value) {
    _openBlock = value;
  }

  String? get frontier => _frontier;

  set frontier(String? value) {
    _frontier = value;
  }

  int? get blockCount => _blockCount;

  set blockCount(int? value) {
    _blockCount = value;
  }

  List<AccountHistoryResponseItem>? get history => _history;

  set history(List<AccountHistoryResponseItem>? value) {
    _history = value;
  }

  List<TXData>? get solids => _solids;

  set solids(List<TXData>? value) {
    _solids = value;
  }

  List<dynamic>? get unified => _unified;

  set unified(List<dynamic>? value) {
    _unified = value;
  }

  bool? get loading => _loading;

  set loading(bool? value) {
    _loading = value;
  }

  bool get historyLoading => _historyLoading;
  set historyLoading(bool value) {
    _historyLoading = value;
  }

  bool get solidsLoading => _solidsLoading;
  set solidsLoading(bool value) {
    _solidsLoading = value;
  }

  bool get unifiedLoading => _unifiedLoading;
  set unifiedLoading(bool value) {
    _unifiedLoading = value;
  }
}
