import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';
import 'package:logger/logger.dart';
import 'package:manta_dart/manta_wallet.dart';
import 'package:manta_dart/messages.dart';

import 'package:nautilus_wallet_flutter/appstate_container.dart';
import 'package:nautilus_wallet_flutter/bus/fcm_update_event.dart';
import 'package:nautilus_wallet_flutter/bus/notification_setting_change_event.dart';
import 'package:nautilus_wallet_flutter/dimens.dart';
import 'package:nautilus_wallet_flutter/localization.dart';
import 'package:nautilus_wallet_flutter/model/available_currency.dart';
import 'package:nautilus_wallet_flutter/model/notification_settings.dart';
import 'package:nautilus_wallet_flutter/network/account_service.dart';
import 'package:nautilus_wallet_flutter/service_locator.dart';
import 'package:nautilus_wallet_flutter/app_icons.dart';
import 'package:nautilus_wallet_flutter/model/address.dart';
import 'package:nautilus_wallet_flutter/model/db/contact.dart';
import 'package:nautilus_wallet_flutter/model/db/user.dart';
import 'package:nautilus_wallet_flutter/model/db/appdb.dart';
import 'package:nautilus_wallet_flutter/styles.dart';
import 'package:nautilus_wallet_flutter/ui/receive/receive_sheet.dart';
import 'package:nautilus_wallet_flutter/ui/send/send_confirm_sheet.dart';
import 'package:nautilus_wallet_flutter/ui/request/request_confirm_sheet.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/app_simpledialog.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/app_text_field.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/buttons.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/dialog.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/one_or_three_address_text.dart';
import 'package:nautilus_wallet_flutter/ui/util/formatters.dart';
import 'package:nautilus_wallet_flutter/ui/util/ui_util.dart';
import 'package:nautilus_wallet_flutter/ui/widgets/sheet_util.dart';
import 'package:nautilus_wallet_flutter/util/manta.dart';
import 'package:nautilus_wallet_flutter/util/numberutil.dart';
import 'package:nautilus_wallet_flutter/util/caseconverter.dart';
import 'package:nautilus_wallet_flutter/util/sharedprefsutil.dart';
import 'package:nautilus_wallet_flutter/util/user_data_util.dart';
import 'package:nautilus_wallet_flutter/themes.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SendSheet extends StatefulWidget {
  final AvailableCurrency localCurrency;
  final User user;
  final String address;
  final String quickSendAmount;

  SendSheet({@required this.localCurrency, this.user, this.address, this.quickSendAmount}) : super();

  _SendSheetState createState() => _SendSheetState();
}

enum AddressStyle { TEXT60, TEXT90, PRIMARY }

class SendSheetHelpers {
  static String stripPrefixes(String addressText) {
    return addressText.replaceAll("@", "").replaceAll("★", "");
  }
}

class _SendSheetState extends State<SendSheet> {
  final Logger log = sl.get<Logger>();

  FocusNode _addressFocusNode;
  FocusNode _amountFocusNode;
  FocusNode _memoFocusNode;
  TextEditingController _addressController;
  TextEditingController _amountController;
  TextEditingController _memoController;

  // States
  AddressStyle _addressStyle;
  String _amountHint;
  String _addressHint;
  String _memoHint;
  String _amountValidationText;
  String _addressValidationText;
  String _memoValidationText;
  String quickSendAmount;
  List<dynamic> _users;
  bool animationOpen;
  // Used to replace address textfield with colorized TextSpan
  bool _addressValidAndUnfocused = false;
  // Set to true when a username is being entered
  bool _isUser = false;
  bool _isFavorite = false;
  // Buttons States (Used because we hide the buttons under certain conditions)
  bool _pasteButtonVisible = true;
  bool _showContactButton = true;
  // Local currency mode/fiat conversion
  bool _localCurrencyMode = false;
  String _lastLocalCurrencyAmount = "";
  String _lastCryptoAmount = "";
  NumberFormat _localCurrencyFormat;

  final int _REQUIRED_CONFIRMATION_HEIGHT = 10;

  // Receive card instance
  ReceiveSheet receive;

  String _rawAmount;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _addressFocusNode = FocusNode();
    _memoFocusNode = FocusNode();
    _amountController = TextEditingController();
    _addressController = TextEditingController();
    _memoController = TextEditingController();
    _addressStyle = AddressStyle.TEXT60;
    _users = [];
    quickSendAmount = widget.quickSendAmount;
    this.animationOpen = false;
    if (widget.user != null) {
      // Setup initial state for contact pre-filled
      _addressController.text = widget.user.getDisplayName();
      _isUser = true;
      _showContactButton = false;
      _pasteButtonVisible = false;
      _addressStyle = AddressStyle.PRIMARY;
    } else if (widget.address != null) {
      // Setup initial state with prefilled address
      _addressController.text = widget.address;
      _showContactButton = false;
      _pasteButtonVisible = false;
      _addressStyle = AddressStyle.TEXT90;
      _addressValidAndUnfocused = true;
    }
    // On amount focus change
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus) {
        if (_rawAmount != null) {
          setState(() {
            _amountController.text = NumberUtil.getRawAsUsableString(_rawAmount).replaceAll(",", "");
            _rawAmount = null;
          });
        }
        if (quickSendAmount != null) {
          _amountController.text = "";
          setState(() {
            quickSendAmount = null;
          });
        }
        setState(() {
          _amountHint = "";
          _amountValidationText = "";
        });
      } else {
        setState(() {
          _amountHint = null;
        });
      }
    });
    // On address focus change
    _addressFocusNode.addListener(() async {
      if (_addressFocusNode.hasFocus) {
        setState(() {
          _addressHint = "";
          _addressValidationText = "";
          _addressValidAndUnfocused = false;
          _pasteButtonVisible = true;
          _addressStyle = AddressStyle.TEXT60;
        });
        _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
        if (_addressController.text.length > 0 && !_addressController.text.startsWith("nano_")) {
          String formattedAddress = SendSheetHelpers.stripPrefixes(_addressController.text);
          if (_addressController.text != formattedAddress) {
            setState(() {
              _addressController.text = formattedAddress;
            });
          }
          var userList = await sl.get<DBHelper>().getUserContactSuggestionsWithNameLike(formattedAddress);
          if (userList != null) {
            setState(() {
              _users = userList;
            });
          }
        }

        if (_addressController.text.length == 0) {
          setState(() {
            _users = [];
          });
        }
      } else {
        setState(() {
          _addressHint = null;
          _users = [];
          if (Address(_addressController.text).isValid()) {
            _addressValidAndUnfocused = true;
          }
          if (_addressController.text.length == 0) {
            _pasteButtonVisible = true;
          }
        });
        if (_addressController.text.length > 0) {
          String formattedAddress = SendSheetHelpers.stripPrefixes(_addressController.text);
          // check if in the username db:
          String address;
          String type;
          var user = await sl.get<DBHelper>().getUserOrContactWithName(formattedAddress);
          if (user != null) {
            type = user.type;
            if (_addressController.text != user.getDisplayName()) {
              setState(() {
                _addressController.text = user.getDisplayName();
              });
            }
          } else {
            // check if UD or ENS address
            if (_addressController.text.contains(".")) {
              // check if UD domain:
              address = await sl.get<AccountService>().checkUnstoppableDomain(formattedAddress);
              if (address != null) {
                type = UserTypes.UD;
              } else {
                // check if ENS domain:
                address = await sl.get<AccountService>().checkENSDomain(formattedAddress);
                if (address != null) {
                  type = UserTypes.ENS;
                }
              }
            }
          }

          if (type != null) {
            setState(() {
              _pasteButtonVisible = false;
              _addressStyle = AddressStyle.PRIMARY;
            });

            if (address != null && user == null) {
              // add to the db if missing:
              User user = new User(username: formattedAddress, address: address, type: type, is_blocked: false);
              await sl.get<DBHelper>().addUser(user);
            }
          } else {
            setState(() {
              _addressStyle = AddressStyle.TEXT60;
            });
          }
        }
      }
    });
    // On memo focus change
    _memoFocusNode.addListener(() {
      if (_memoFocusNode.hasFocus) {
        setState(() {
          _memoHint = "";
          _memoValidationText = "";
        });
      } else {
        setState(() {
          _memoHint = null;
        });
      }
    });

    // Set initial currency format
    _localCurrencyFormat = NumberFormat.currency(locale: widget.localCurrency.getLocale().toString(), symbol: widget.localCurrency.getCurrencySymbol());
    // Set quick send amount
    if (quickSendAmount != null) {
      _amountController.text = NumberUtil.getRawAsUsableString(quickSendAmount).replaceAll(",", "");
    }
  }

  void _showMantaAnimation() {
    animationOpen = true;
    Navigator.of(context).push(AnimationLoadingOverlay(
        AnimationType.MANTA, StateContainer.of(context).curTheme.animationOverlayStrong, StateContainer.of(context).curTheme.animationOverlayMedium,
        onPoppedCallback: () => animationOpen = false));
  }

  Future<bool> showNotificationDialog() async {
    switch (await showDialog<NotificationOptions>(
        context: context,
        barrierColor: StateContainer.of(context).curTheme.barrier,
        builder: (BuildContext context) {
          return AppSimpleDialog(
            title: Text(
              AppLocalization.of(context).notifications,
              style: AppStyles.textStyleDialogHeader(context),
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Text(AppLocalization.of(context).notificationInfo + "\n", style: AppStyles.textStyleParagraph(context)),
              ),
              AppSimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NotificationOptions.ON);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    AppLocalization.of(context).onStr,
                    style: AppStyles.textStyleDialogOptions(context),
                  ),
                ),
              ),
              AppSimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NotificationOptions.OFF);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    AppLocalization.of(context).off,
                    style: AppStyles.textStyleDialogOptions(context),
                  ),
                ),
              ),
            ],
          );
        })) {
      case NotificationOptions.ON:
        EventTaxiImpl.singleton().fire(NotificationSettingChangeEvent(isOn: true));
        FirebaseMessaging.instance.requestPermission();
        FirebaseMessaging.instance.getToken().then((fcmToken) {
          EventTaxiImpl.singleton().fire(FcmUpdateEvent(token: fcmToken));
        });
        return true;
      case NotificationOptions.OFF:
        EventTaxiImpl.singleton().fire(NotificationSettingChangeEvent(isOn: false));
        FirebaseMessaging.instance.getToken().then((fcmToken) {
          EventTaxiImpl.singleton().fire(FcmUpdateEvent(token: fcmToken));
        });
        return false;
      default:
        return false;
    }
  }

  Future<bool> showNeedVerificationAlert() async {
    switch (await showDialog<int>(
        context: context,
        barrierColor: StateContainer.of(context).curTheme.barrier,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              AppLocalization.of(context).needVerificationAlertHeader,
              style: AppStyles.textStyleDialogHeader(context),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(AppLocalization.of(context).needVerificationAlert + "\n\n", style: AppStyles.textStyleParagraph(context)),
              ],
            ),
            actions: <Widget>[
              AppSimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    AppLocalization.of(context).goToQRCode,
                    style: AppStyles.textStyleDialogOptions(context),
                  ),
                ),
              ),
              AppSimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 0);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    AppLocalization.of(context).ok,
                    style: AppStyles.textStyleDialogOptions(context),
                  ),
                ),
              ),
            ],
          );
        })) {
      case 1:
        // go to qr code
        if (receive == null) {
          return false;
        }
        Navigator.of(context).pop();
        // TODO: BACKLOG: this is a roundabout solution to get the qr code to show up
        // probably better to do with an event bus
        Sheets.showAppHeightNineSheet(context: context, widget: receive);
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  Future<void> showFallbackConnectedAlert() async {
    await showDialog<bool>(
        context: context,
        barrierColor: StateContainer.of(context).curTheme.barrier,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              AppLocalization.of(context).fallbackHeader,
              style: AppStyles.textStyleDialogHeader(context),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(AppLocalization.of(context).fallbackInfo + "\n\n", style: AppStyles.textStyleParagraph(context)),
              ],
            ),
            actions: <Widget>[
              AppSimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    AppLocalization.of(context).ok,
                    style: AppStyles.textStyleDialogOptions(context),
                  ),
                ),
              ),
            ],
          );
        });
  }

  void paintQrCode({String address}) {
    QrPainter painter = QrPainter(
      data: address == null ? StateContainer.of(context).wallet.address : address,
      version: 6,
      gapless: false,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );
    painter.toImageData(MediaQuery.of(context).size.width).then((byteData) {
      setState(() {
        receive = ReceiveSheet(
          localCurrency: StateContainer.of(context).curCurrency,
          address: StateContainer.of(context).wallet.address,
          qrWidget: Container(width: MediaQuery.of(context).size.width / 2.675, child: Image.memory(byteData.buffer.asUint8List())),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Create QR ahead of time because it improves performance this way
    if (receive == null && StateContainer.of(context).wallet != null) {
      paintQrCode();
    }
    // The main column that holds everything
    return SafeArea(
        minimum: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.035),
        child: Column(
          children: <Widget>[
            // A row for the header of the sheet, balance text and close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                //Empty SizedBox
                SizedBox(
                  width: 60,
                  height: 60,
                ),

                // Container for the header, address and balance text
                Column(
                  children: <Widget>[
                    // Sheet handle
                    Container(
                      margin: EdgeInsets.only(top: 10),
                      height: 5,
                      width: MediaQuery.of(context).size.width * 0.15,
                      decoration: BoxDecoration(
                        color: StateContainer.of(context).curTheme.text10,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 15.0),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                      child: Column(
                        children: <Widget>[
                          // Header
                          AutoSizeText(
                            CaseChange.toUpperCase(AppLocalization.of(context).sendFrom, context),
                            style: AppStyles.textStyleHeader(context),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            stepGranularity: 0.1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                //Empty SizedBox
                SizedBox(
                  width: 60,
                  height: 60,
                ),
              ],
            ),

            // account / wallet name:
            Container(
              margin: EdgeInsets.only(top: 10.0, left: 30, right: 30),
              child: Container(
                child: RichText(
                  textAlign: TextAlign.start,
                  text: TextSpan(
                    text: '',
                    children: [
                      TextSpan(
                        text: StateContainer.of(context).selectedAccount.name,
                        style: TextStyle(
                          color: StateContainer.of(context).curTheme.text60,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'NunitoSans',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Address Text
            // Container(
            //   margin: EdgeInsets.symmetric(horizontal: 30),
            //   child: OneOrThreeLineAddressText(address: StateContainer.of(context).wallet.address, type: AddressTextType.PRIMARY60),
            // ),
            // Balance Text
            FutureBuilder(
              future: sl.get<SharedPrefsUtil>().getPriceConversion(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.hasData && snapshot.data != null && snapshot.data != PriceConversion.HIDDEN) {
                  return Container(
                    child: RichText(
                      textAlign: TextAlign.start,
                      text: TextSpan(
                        text: '',
                        children: [
                          TextSpan(
                            text: "(",
                            style: TextStyle(
                              color: StateContainer.of(context).curTheme.primary60,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w100,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                          displayCurrencyAmount(
                            context,
                            TextStyle(
                              color: StateContainer.of(context).curTheme.primary60,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'NunitoSans',
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          TextSpan(
                            text: _localCurrencyMode
                                ? StateContainer.of(context)
                                    .wallet
                                    .getLocalCurrencyPrice(StateContainer.of(context).curCurrency, locale: StateContainer.of(context).currencyLocale)
                                : getCurrencySymbol(context) + StateContainer.of(context).wallet.getAccountBalanceDisplay(context),
                            style: TextStyle(
                              color: StateContainer.of(context).curTheme.primary60,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                          TextSpan(
                            text: ")",
                            style: TextStyle(
                              color: StateContainer.of(context).curTheme.primary60,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w100,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  child: Text(
                    "*******",
                    style: TextStyle(
                      color: Colors.transparent,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w100,
                      fontFamily: 'NunitoSans',
                    ),
                  ),
                );
              },
            ),
            // A main container that holds everything
            Expanded(
              child: Container(
                margin: EdgeInsets.only(top: 5, bottom: 5),
                child: GestureDetector(
                  onTap: () {
                    // Clear focus of our fields when tapped in this empty space
                    _addressFocusNode.unfocus();
                    _amountFocusNode.unfocus();
                    _memoFocusNode.unfocus();
                  },
                  child: KeyboardAvoider(
                    duration: Duration(milliseconds: 0),
                    autoScroll: true,
                    focusPadding: 40,
                    child: Column(
                      children: <Widget>[
                        Stack(
                          children: <Widget>[
                            // Enter Amount container + Enter Amount Error container
                            Column(
                              children: <Widget>[
                                // ******* Enter Amount Container ******* //
                                getEnterAmountContainer(),
                                // ******* Enter Amount Container End ******* //

                                // ******* Enter Amount Error Container ******* //
                                Container(
                                  alignment: AlignmentDirectional(0, 0),
                                  margin: EdgeInsets.only(top: 3),
                                  child: Text(_amountValidationText ?? "",
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: StateContainer.of(context).curTheme.primary,
                                        fontFamily: 'NunitoSans',
                                        fontWeight: FontWeight.w600,
                                      )),
                                ),
                                // ******* Enter Amount Error Container End ******* //
                              ],
                            ),

                            // Column for Enter Address container + Enter Address Error container
                            Column(
                              children: <Widget>[
                                Container(
                                  alignment: Alignment.topCenter,
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: <Widget>[
                                      Container(
                                        margin:
                                            EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.105, right: MediaQuery.of(context).size.width * 0.105),
                                        alignment: Alignment.bottomCenter,
                                        constraints: BoxConstraints(maxHeight: 160, minHeight: 0),
                                        // ********************************************* //
                                        // ********* The pop-up Contacts List ********* //
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(25),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(25),
                                              color: StateContainer.of(context).curTheme.backgroundDarkest,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                              margin: EdgeInsets.only(bottom: 50),
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                padding: EdgeInsets.only(bottom: 0, top: 0),
                                                itemCount: _users.length,
                                                itemBuilder: (context, index) {
                                                  return _buildUserItem(_users[index]);
                                                },
                                              ), // ********* The pop-up Contacts List End ********* //
                                              // ************************************************** //
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ******* Enter Address Container ******* //
                                      getEnterAddressContainer(),
                                      // ******* Enter Address Container End ******* //
                                    ],
                                  ),
                                ),

                                // ******* Enter Address Error Container ******* //
                                Container(
                                  alignment: AlignmentDirectional(0, 0),
                                  margin: EdgeInsets.only(top: 3),
                                  child: Text(_addressValidationText ?? "",
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: StateContainer.of(context).curTheme.primary,
                                        fontFamily: 'NunitoSans',
                                        fontWeight: FontWeight.w600,
                                      )),
                                ),
                                // ******* Enter Address Error Container End ******* //
                              ],
                            ),

                            // Column for Enter Memo container + Enter Memo Error container
                            Column(
                              children: <Widget>[
                                Container(
                                  alignment: Alignment.topCenter,
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: <Widget>[
                                      Container(
                                        margin:
                                            EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.105, right: MediaQuery.of(context).size.width * 0.105),
                                        alignment: Alignment.bottomCenter,
                                        constraints: BoxConstraints(maxHeight: 174, minHeight: 0),
                                      ),

                                      // ******* Enter Memo Container ******* //
                                      getEnterMemoContainer(),
                                      // ******* Enter Memo Container End ******* //
                                    ],
                                  ),
                                ),

                                // ******* Enter Memo Error Container ******* //
                                Container(
                                  alignment: AlignmentDirectional(0, 0),
                                  margin: EdgeInsets.only(top: 3),
                                  child: Text(_memoValidationText ?? "",
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: StateContainer.of(context).curTheme.primary,
                                        fontFamily: 'NunitoSans',
                                        fontWeight: FontWeight.w600,
                                      )),
                                ),
                                // ******* Enter Memo Error Container End ******* //
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // A column for Enter Amount, Enter Address, Error containers and the pop up list
              ),
            ),

            //A column with "Scan QR Code" and "Send" buttons
            Container(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // Send Button
                      AppButton.buildAppButton(context, AppButtonType.PRIMARY, AppLocalization.of(context).send, [27.0, 0.0, 7.0, 24.0], onPressed: () async {
                        bool validRequest = await _validateRequest();

                        if (!validRequest) {
                          return;
                        }

                        String formattedAddress = SendSheetHelpers.stripPrefixes(_addressController.text);

                        String amountRaw;

                        if (_amountController.text.isEmpty || _amountController.text == "0") {
                          amountRaw = "0";
                        } else {
                          if (_localCurrencyMode) {
                            amountRaw = NumberUtil.getAmountAsRaw(_convertLocalCurrencyToCrypto());
                          } else {
                            amountRaw = _rawAmount ?? (StateContainer.of(context).nyanoMode)
                                ? NumberUtil.getNyanoAmountAsRaw(_amountController.text)
                                : NumberUtil.getAmountAsRaw(_amountController.text);
                          }
                        }

                        // verifyies the input is a user in the db
                        if (!_addressController.text.startsWith("nano_")) {
                          // Need to make sure its a valid contact or user
                          var user = await sl.get<DBHelper>().getUserOrContactWithName(formattedAddress);
                          if (user == null) {
                            setState(() {
                              if (_addressController.text.startsWith("★")) {
                                _addressValidationText = AppLocalization.of(context).favoriteInvalid;
                              } else if (_addressController.text.startsWith("@")) {
                                _addressValidationText = AppLocalization.of(context).usernameInvalid;
                              } else if (_addressController.text.contains(".")) {
                                _addressValidationText = AppLocalization.of(context).domainInvalid;
                              }
                            });
                          } else {
                            Sheets.showAppHeightNineSheet(
                                context: context,
                                widget: SendConfirmSheet(
                                    amountRaw: amountRaw,
                                    destination: user.address,
                                    contactName: user.getDisplayName(),
                                    maxSend: _isMaxSend(),
                                    localCurrency: _localCurrencyMode ? _amountController.text : null,
                                    memo: _memoController.text));
                          }
                        } else {
                          Sheets.showAppHeightNineSheet(
                              context: context,
                              widget: SendConfirmSheet(
                                  amountRaw: amountRaw,
                                  destination: _addressController.text,
                                  maxSend: _isMaxSend(),
                                  localCurrency: _localCurrencyMode ? _amountController.text : null,
                                  memo: _memoController.text));
                        }
                      }),
                      // Request Button
                      AppButton.buildAppButton(context, AppButtonType.PRIMARY, AppLocalization.of(context).request, [7.0, 0.0, 27.0, 24.0],
                          onPressed: () async {
                        bool validRequest = await _validateRequest(isRequest: true);

                        if (!validRequest) {
                          return;
                        }
                        String formattedAddress = SendSheetHelpers.stripPrefixes(_addressController.text);
                        String amountRaw;
                        if (_amountController.text.isEmpty || _amountController.text == "0") {
                          amountRaw = "0";
                        } else {
                          if (_localCurrencyMode) {
                            amountRaw = NumberUtil.getAmountAsRaw(_convertLocalCurrencyToCrypto());
                          } else {
                            amountRaw = _rawAmount ?? (StateContainer.of(context).nyanoMode)
                                ? NumberUtil.getNyanoAmountAsRaw(_amountController.text)
                                : NumberUtil.getAmountAsRaw(_amountController.text);
                          }
                        }

                        // verifyies the input is a user in the db
                        if (_addressController.text.startsWith("@") || _addressController.text.startsWith("★") || _addressController.text.contains(".")) {
                          // Need to make sure its a valid contact or user
                          var user = await sl.get<DBHelper>().getUserOrContactWithName(formattedAddress);
                          if (user == null) {
                            setState(() {
                              if (_addressController.text.startsWith("★")) {
                                _addressValidationText = AppLocalization.of(context).favoriteInvalid;
                              } else if (_addressController.text.startsWith("@")) {
                                _addressValidationText = AppLocalization.of(context).usernameInvalid;
                              } else if (_addressController.text.contains(".")) {
                                _addressValidationText = AppLocalization.of(context).domainInvalid;
                              }
                            });
                          } else {
                            Sheets.showAppHeightNineSheet(
                                context: context,
                                widget: RequestConfirmSheet(
                                  amountRaw: amountRaw,
                                  destination: user.address,
                                  contactName: user.getDisplayName(),
                                  localCurrency: _localCurrencyMode ? _amountController.text : null,
                                  memo: _memoController.text,
                                ));
                          }
                        } else if (_addressController.text.contains(".")) {
                          String address;

                          // check if UD domain:
                          address = await sl.get<AccountService>().checkUnstoppableDomain(_addressController.text);
                          if (address != null) {
                          } else {
                            // check if ENS domain:
                            address = await sl.get<AccountService>().checkENSDomain(_addressController.text);
                          }

                          if (address == null) {
                            _addressValidationText = AppLocalization.of(context).domainInvalid;
                          }
                        } else {
                          Sheets.showAppHeightNineSheet(
                              context: context,
                              widget: RequestConfirmSheet(
                                  amountRaw: amountRaw,
                                  destination: _addressController.text,
                                  localCurrency: _localCurrencyMode ? _amountController.text : null,
                                  memo: _memoController.text));
                        }
                      }),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      // Scan QR Code Button
                      AppButton.buildAppButton(context, AppButtonType.PRIMARY_OUTLINE, AppLocalization.of(context).scanQrCode, Dimens.BUTTON_BOTTOM_DIMENS,
                          onPressed: () async {
                        UIUtil.cancelLockEvent();
                        String scanResult = await UserDataUtil.getQRData(DataType.MANTA_ADDRESS, context);
                        if (scanResult == null) {
                          UIUtil.showSnackbar(AppLocalization.of(context).qrInvalidAddress, context);
                        } else if (QRScanErrs.ERROR_LIST.contains(scanResult)) {
                          return;
                        } else if (MantaWallet.parseUrl(scanResult) != null) {
                          try {
                            _showMantaAnimation();
                            // Get manta payment request
                            MantaWallet manta = MantaWallet(scanResult);
                            PaymentRequestMessage paymentRequest = await MantaUtil.getPaymentDetails(manta);
                            if (animationOpen) {
                              Navigator.of(context).pop();
                            }
                            MantaUtil.processPaymentRequest(context, manta, paymentRequest);
                          } catch (e) {
                            if (animationOpen) {
                              Navigator.of(context).pop();
                            }
                            log.e('Failed to make manta request ${e.toString()}', e);
                            UIUtil.showSnackbar(AppLocalization.of(context).mantaError, context);
                          }
                        } else {
                          // Is a URI
                          Address address = Address(scanResult);
                          // See if this address belongs to a contact or username
                          dynamic user = await sl.get<DBHelper>().getUserOrContactWithAddress(address.address);
                          if (user != null) {
                            // Is a user
                            if (mounted) {
                              setState(() {
                                _isUser = true;
                                _addressValidationText = "";
                                _addressStyle = AddressStyle.PRIMARY;
                                _pasteButtonVisible = false;
                                _showContactButton = false;
                              });
                              _addressController.text = user.getDisplayName();
                            }
                          } else {
                            // Not a contact or username
                            if (mounted) {
                              setState(() {
                                _isUser = false;
                                _addressValidationText = "";
                                _addressStyle = AddressStyle.TEXT90;
                                _pasteButtonVisible = false;
                                _showContactButton = false;
                              });
                              _addressController.text = address.address;
                              _addressFocusNode.unfocus();
                              setState(() {
                                _addressValidAndUnfocused = true;
                              });
                            }
                          }
                          // If amount is present, fill it and go to SendConfirm
                          if (address.amount != null) {
                            bool hasError = false;
                            BigInt amountBigInt = BigInt.tryParse(address.amount);
                            if (amountBigInt != null && amountBigInt < BigInt.from(10).pow(24)) {
                              hasError = true;
                              UIUtil.showSnackbar(AppLocalization.of(context).minimumSend.replaceAll("%1", "0.000001"), context);
                            } else if (_localCurrencyMode && mounted) {
                              toggleLocalCurrency();
                              _amountController.text = getRawAsThemeAwareAmount(context, address.amount);
                            } else if (mounted) {
                              setState(() {
                                _rawAmount = address.amount;
                                // If raw amount has more precision than we support show a special indicator
                                if ((StateContainer.of(context).nyanoMode)) {
                                  _amountController.text = NumberUtil.getRawAsUsableString(_rawAmount).replaceAll(",", "");
                                } else {
                                  if (NumberUtil.getRawAsUsableString(_rawAmount).replaceAll(",", "") ==
                                      NumberUtil.getRawAsUsableDecimal(_rawAmount).toString()) {
                                    _amountController.text = NumberUtil.getRawAsUsableString(_rawAmount).replaceAll(",", "");
                                  } else {
                                    _amountController.text =
                                        NumberUtil.truncateDecimal(NumberUtil.getRawAsUsableDecimal(address.amount), digits: 6).toStringAsFixed(6) + "~";
                                  }
                                }
                              });
                              _addressFocusNode.unfocus();
                            }
                            // If balance is sufficient go to SendConfirm
                            if (!hasError && StateContainer.of(context).wallet.accountBalance > amountBigInt) {
                              // Go to confirm sheet
                              Sheets.showAppHeightNineSheet(
                                  context: context,
                                  widget: SendConfirmSheet(
                                      amountRaw: _localCurrencyMode
                                          ? NumberUtil.getAmountAsRaw(_convertLocalCurrencyToCrypto())
                                          : _rawAmount == null
                                              ? NumberUtil.getAmountAsRaw(_amountController.text)
                                              : _rawAmount,
                                      destination: user != null ? user.address : address.address,
                                      contactName: user.getDisplayName(),
                                      maxSend: _isMaxSend(),
                                      localCurrency: _localCurrencyMode ? _amountController.text : null));
                            }
                          }
                        }
                      })
                    ],
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  String _convertLocalCurrencyToCrypto() {
    String convertedAmt = _amountController.text.replaceAll(",", ".");
    convertedAmt = NumberUtil.sanitizeNumber(convertedAmt);
    if (convertedAmt.isEmpty) {
      return "";
    }
    Decimal valueLocal = Decimal.parse(convertedAmt);
    Decimal conversion = Decimal.parse(StateContainer.of(context).wallet.localCurrencyConversion);
    return NumberUtil.truncateDecimal(valueLocal / conversion).toString();
  }

  String _convertCryptoToLocalCurrency() {
    String convertedAmt = NumberUtil.sanitizeNumber(_amountController.text, maxDecimalDigits: 2);
    if (convertedAmt.isEmpty) {
      return "";
    }
    Decimal valueCrypto = Decimal.parse(convertedAmt);
    Decimal conversion = Decimal.parse(StateContainer.of(context).wallet.localCurrencyConversion);
    convertedAmt = NumberUtil.truncateDecimal(valueCrypto * conversion, digits: 2).toString();
    convertedAmt = convertedAmt.replaceAll(".", _localCurrencyFormat.symbols.DECIMAL_SEP);
    convertedAmt = _localCurrencyFormat.currencySymbol + convertedAmt;
    return convertedAmt;
  }

  // Determine if this is a max send or not by comparing balances
  bool _isMaxSend() {
    // Sanitize commas
    if (_amountController.text.isEmpty) {
      return false;
    }
    try {
      String textField = _amountController.text;
      String balance;
      if (_localCurrencyMode) {
        balance =
            StateContainer.of(context).wallet.getLocalCurrencyPrice(StateContainer.of(context).curCurrency, locale: StateContainer.of(context).currencyLocale);
      } else {
        balance = StateContainer.of(context).wallet.getAccountBalanceDisplay(context).replaceAll(r",", "");
      }
      // Convert to Integer representations
      int textFieldInt;
      int balanceInt;
      if (_localCurrencyMode) {
        // Sanitize currency values into plain integer representations
        textField = textField.replaceAll(",", ".");
        String sanitizedTextField = NumberUtil.sanitizeNumber(textField);
        balance = balance.replaceAll(_localCurrencyFormat.symbols.GROUP_SEP, "");
        balance = balance.replaceAll(",", ".");
        String sanitizedBalance = NumberUtil.sanitizeNumber(balance);
        textFieldInt = (Decimal.parse(sanitizedTextField) * Decimal.fromInt(pow(10, NumberUtil.maxDecimalDigits))).toInt();
        balanceInt = (Decimal.parse(sanitizedBalance) * Decimal.fromInt(pow(10, NumberUtil.maxDecimalDigits))).toInt();
      } else {
        textField = textField.replaceAll(",", "");
        textFieldInt = (Decimal.parse(textField) * Decimal.fromInt(pow(10, NumberUtil.maxDecimalDigits))).toInt();
        balanceInt = (Decimal.parse(balance) * Decimal.fromInt(pow(10, NumberUtil.maxDecimalDigits))).toInt();
      }
      return textFieldInt == balanceInt;
    } catch (e) {
      return false;
    }
  }

  void toggleLocalCurrency() {
    // Keep a cache of previous amounts because, it's kinda nice to see approx what nano is worth
    // this way you can tap button and tap back and not end up with X.9993451 NANO
    if (_localCurrencyMode) {
      // Switching to crypto-mode
      String cryptoAmountStr;
      // Check out previous state
      if (_amountController.text == _lastLocalCurrencyAmount) {
        cryptoAmountStr = _lastCryptoAmount;
      } else {
        _lastLocalCurrencyAmount = _amountController.text;
        _lastCryptoAmount = _convertLocalCurrencyToCrypto();
        cryptoAmountStr = _lastCryptoAmount;
      }
      setState(() {
        _localCurrencyMode = false;
      });
      Future.delayed(Duration(milliseconds: 50), () {
        _amountController.text = cryptoAmountStr;
        _amountController.selection = TextSelection.fromPosition(TextPosition(offset: cryptoAmountStr.length));
      });
    } else {
      // Switching to local-currency mode
      String localAmountStr;
      // Check our previous state
      if (_amountController.text == _lastCryptoAmount) {
        localAmountStr = _lastLocalCurrencyAmount;
      } else {
        _lastCryptoAmount = _amountController.text;
        _lastLocalCurrencyAmount = _convertCryptoToLocalCurrency();
        localAmountStr = _lastLocalCurrencyAmount;
      }
      setState(() {
        _localCurrencyMode = true;
      });
      Future.delayed(Duration(milliseconds: 50), () {
        _amountController.text = localAmountStr;
        _amountController.selection = TextSelection.fromPosition(TextPosition(offset: localAmountStr.length));
      });
    }
  }

  // Build contact items for the list
  Widget _buildUserItem(User user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 42,
          width: double.infinity - 5,
          child: FlatButton(
            onPressed: () {
              _addressController.text = user.getDisplayName(ignoreNickname: !_isFavorite);
              _addressFocusNode.unfocus();
              setState(() {
                _isUser = true;
                _showContactButton = false;
                _pasteButtonVisible = false;
                _addressStyle = AddressStyle.PRIMARY;
                _addressValidationText = "";
              });
            },
            child: Text(user.getDisplayName(ignoreNickname: !_isFavorite), textAlign: TextAlign.center, style: AppStyles.textStyleAddressPrimary(context)),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 25),
          height: 1,
          color: StateContainer.of(context).curTheme.text03,
        ),
      ],
    );
  }

  /// Validate form data to see if valid
  /// @returns true if valid, false otherwise
  Future<bool> _validateRequest({bool isRequest = false}) async {
    bool isValid = true;
    _amountFocusNode.unfocus();
    _addressFocusNode.unfocus();
    _memoFocusNode.unfocus();
    // Validate amount
    if (_amountController.text.trim().isEmpty && isRequest && _memoController.text.trim().isNotEmpty) {
      isValid = false;
      setState(() {
        _amountValidationText = AppLocalization.of(context).amountMissing;
      });
    } else {
      String bananoAmount = _localCurrencyMode
          ? _convertLocalCurrencyToCrypto()
          : _rawAmount == null
              ? _amountController.text
              : NumberUtil.getRawAsUsableString(_rawAmount);
      if (bananoAmount == null || bananoAmount.isEmpty) {
        bananoAmount = "0";
      }
      BigInt balanceRaw = StateContainer.of(context).wallet.accountBalance;
      BigInt sendAmount = BigInt.tryParse(getThemeAwareAmountAsRaw(context, bananoAmount));
      if (sendAmount == null || sendAmount == BigInt.zero) {
        if (_memoController.text.trim().isEmpty || isRequest) {
          isValid = false;
          setState(() {
            _amountValidationText = AppLocalization.of(context).amountMissing;
          });
        } else {
          setState(() {
            _amountValidationText = "";
          });
        }
      } else if (sendAmount > balanceRaw && !isRequest) {
        isValid = false;
        setState(() {
          _amountValidationText = AppLocalization.of(context).insufficientBalance;
        });
      } else {
        setState(() {
          _amountValidationText = "";
        });
      }
    }
    // Validate address
    bool isUser = _addressController.text.startsWith("@");
    bool isFavorite = _addressController.text.startsWith("★");
    bool isDomain = _addressController.text.contains(".");
    bool isNano = _addressController.text.startsWith("nano_");
    if (_addressController.text.trim().isEmpty) {
      isValid = false;
      setState(() {
        _addressValidationText = AppLocalization.of(context).addressMissing;
        _pasteButtonVisible = true;
      });
    } else if (!isFavorite && !isUser && !isDomain && !Address(_addressController.text).isValid()) {
      isValid = false;
      setState(() {
        _addressValidationText = AppLocalization.of(context).invalidAddress;
        _pasteButtonVisible = true;
      });
    } else if (!isUser && !isFavorite) {
      setState(() {
        _addressValidationText = "";
        _pasteButtonVisible = false;
      });
      _addressFocusNode.unfocus();
    }
    if (isValid) {
      // notifications must be turned on if sending a request or memo:
      bool notificationsEnabled = await sl.get<SharedPrefsUtil>().getNotificationsOn();

      if ((isRequest || _memoController.text.isNotEmpty) && !notificationsEnabled) {
        bool notificationTurnedOn = await showNotificationDialog();
        if (!notificationTurnedOn) {
          isValid = false;
        } else {
          // not sure why this is needed to get it to update:
          // probably event bus related:
          await sl.get<SharedPrefsUtil>().setNotificationsOn(true);
        }
      }

      if (isValid && isRequest) {
        // still valid && you have to have a nautilus username to send requests:
        if (StateContainer.of(context).wallet.username == null && StateContainer.of(context).wallet.confirmationHeight < _REQUIRED_CONFIRMATION_HEIGHT) {
          isValid = false;
          await showNeedVerificationAlert();
        }
      }

      if (isValid && sl.get<AccountService>().fallbackConnected) {
        if (_memoController.text.trim().isNotEmpty) {
          isValid = false;
          await showFallbackConnectedAlert();
        }
      }
    }
    return isValid;
  }

  //************ Enter Amount Container Method ************//
  //*******************************************************//
  getEnterAmountContainer() {
    return AppTextField(
      focusNode: _amountFocusNode,
      controller: _amountController,
      topMargin: 30,
      cursorColor: StateContainer.of(context).curTheme.primary,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16.0,
        color: StateContainer.of(context).curTheme.primary,
        fontFamily: 'NunitoSans',
      ),
      inputFormatters: _rawAmount == null
          ? [
              LengthLimitingTextInputFormatter(13),
              _localCurrencyMode
                  ? CurrencyFormatter(
                      decimalSeparator: _localCurrencyFormat.symbols.DECIMAL_SEP, commaSeparator: _localCurrencyFormat.symbols.GROUP_SEP, maxDecimalDigits: 2)
                  : CurrencyFormatter(maxDecimalDigits: NumberUtil.maxDecimalDigits),
              LocalCurrencyFormatter(active: _localCurrencyMode, currencyFormat: _localCurrencyFormat)
            ]
          : [LengthLimitingTextInputFormatter(13)],
      onChanged: (text) {
        // Always reset the error message to be less annoying
        setState(() {
          _amountValidationText = "";
          // Reset the raw amount
          _rawAmount = null;
        });
      },
      textInputAction: TextInputAction.next,
      maxLines: null,
      autocorrect: false,
      hintText: _amountHint ?? AppLocalization.of(context).enterAmount,
      prefixButton: _rawAmount == null
          ? TextFieldButton(
              icon: AppIcons.swapcurrency,
              onPressed: () {
                toggleLocalCurrency();
              },
            )
          : null,
      suffixButton: TextFieldButton(
        icon: AppIcons.max,
        onPressed: () {
          if (_isMaxSend()) {
            return;
          }
          if (!_localCurrencyMode) {
            _amountController.text = StateContainer.of(context).wallet.getAccountBalanceDisplay(context).replaceAll(r",", "");
            _amountController.selection = TextSelection.fromPosition(TextPosition(offset: _amountController.text.length));
            _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
            // setState(() {
            //   // force max send button to fade out
            // });
            // FocusScope.of(context).unfocus();
            // if (!Address(_addressController.text).isValid()) {
            //   FocusScope.of(context).requestFocus(_addressFocusNode);
            // }
          } else {
            String localAmount = StateContainer.of(context)
                .wallet
                .getLocalCurrencyPrice(StateContainer.of(context).curCurrency, locale: StateContainer.of(context).currencyLocale);
            localAmount = localAmount.replaceAll(_localCurrencyFormat.symbols.GROUP_SEP, "");
            localAmount = localAmount.replaceAll(_localCurrencyFormat.symbols.DECIMAL_SEP, ".");
            localAmount = NumberUtil.sanitizeNumber(localAmount).replaceAll(".", _localCurrencyFormat.symbols.DECIMAL_SEP);
            _amountController.text = _localCurrencyFormat.currencySymbol + localAmount;
            _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
          }
        },
      ),
      // fadeSuffixOnCondition: true,
      suffixShowFirstCondition: !_isMaxSend(),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      onSubmitted: (text) {
        FocusScope.of(context).unfocus();
        if (!Address(_addressController.text).isValid()) {
          FocusScope.of(context).requestFocus(_addressFocusNode);
        }
      },
    );
  } //************ Enter Address Container Method End ************//
  //*************************************************************//

  //************ Enter Address Container Method ************//
  //*******************************************************//
  getEnterAddressContainer() {
    return AppTextField(
        topMargin: 115,
        padding: _addressValidAndUnfocused ? EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0) : EdgeInsets.zero,
        // padding: EdgeInsets.zero,
        textAlign: TextAlign.center,
        // textAlign: (_isUser || _addressController.text.length == 0) ? TextAlign.center : TextAlign.start,
        focusNode: _addressFocusNode,
        controller: _addressController,
        cursorColor: StateContainer.of(context).curTheme.primary,
        inputFormatters: [
          _isUser ? LengthLimitingTextInputFormatter(20) : LengthLimitingTextInputFormatter(65),
        ],
        // textInputAction: TextInputAction.done,
        textInputAction: TextInputAction.next,
        maxLines: null,
        autocorrect: false,
        hintText: _addressHint ?? AppLocalization.of(context).enterUserOrAddress,
        prefixButton: TextFieldButton(
          icon: AppIcons.star,
          onPressed: () {
            if (_showContactButton && _users.length == 0) {
              // Show menu
              FocusScope.of(context).requestFocus(_addressFocusNode);
              if (_addressController.text.length == 0) {
                _addressController.text = "★";
                _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
              }
              sl.get<DBHelper>().getContacts().then((userList) {
                final nicknames = Set();
                userList.retainWhere((x) => nicknames.add(x.nickname));
                setState(() {
                  _isFavorite = true;
                  _users = userList;
                });
              });
            }
          },
        ),
        fadePrefixOnCondition: true,
        prefixShowFirstCondition: _showContactButton && _users.length == 0,
        suffixButton: TextFieldButton(
          icon: AppIcons.paste,
          onPressed: () {
            if (!_pasteButtonVisible) {
              return;
            }
            Clipboard.getData("text/plain").then((ClipboardData data) {
              if (data == null || data.text == null) {
                return;
              }
              Address address = Address(data.text);
              if (address.isValid()) {
                sl.get<DBHelper>().getUserOrContactWithAddress(address.address).then((user) {
                  if (user == null) {
                    setState(() {
                      _isUser = false;
                      _addressValidationText = "";
                      _addressStyle = AddressStyle.TEXT90;
                      _pasteButtonVisible = false;
                      _showContactButton = false;
                    });
                    _addressController.text = address.address;
                    _addressFocusNode.unfocus();
                    setState(() {
                      _addressValidAndUnfocused = true;
                    });
                  } else {
                    // Is a user
                    setState(() {
                      _addressController.text = user.getDisplayName();
                      _addressFocusNode.unfocus();
                      _users = [];
                      _isUser = true;
                      _addressValidationText = "";
                      _addressStyle = AddressStyle.PRIMARY;
                      _pasteButtonVisible = false;
                      _showContactButton = false;
                    });
                  }
                });
              }
            });
          },
        ),
        fadeSuffixOnCondition: true,
        suffixShowFirstCondition: _pasteButtonVisible,
        style: _addressStyle == AddressStyle.TEXT60
            ? AppStyles.textStyleAddressText60(context)
            : _addressStyle == AddressStyle.TEXT90
                ? AppStyles.textStyleAddressText90(context)
                : AppStyles.textStyleAddressPrimary(context),
        onChanged: (text) async {
          bool isUser = false;
          bool isDomain = text.contains(".");
          bool isFavorite = text.startsWith("★");
          bool isNano = text.startsWith("nano_");

          // prevent spaces:
          if (text.contains(" ")) {
            text = text.replaceAll(" ", "");
            _addressController.text = text;
            _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
          }

          // remove the @ if it's the only text there:
          // if (text == "@" || text == "★" || text == "nano_") {
          //   _addressController.text = "";
          //   _addressController.selection = TextSelection.fromPosition(TextPosition(offset: _addressController.text.length));
          //   setState(() {
          //     _showContactButton = true;
          //     _pasteButtonVisible = true;
          //     _isUser = false;
          //     _users = [];
          //   });
          //   return;
          // }

          if (text.length > 0) {
            setState(() {
              _showContactButton = false;
              if (!_addressValidAndUnfocused) {
                _pasteButtonVisible = true;
              }
            });
          } else {
            setState(() {
              _showContactButton = true;
              _pasteButtonVisible = true;
            });
          }

          if (text.length > 0 && !isUser && !isNano) {
            isUser = true;
          }

          if (text.length > 0 && text.startsWith("nano_")) {
            isUser = false;
          }

          if (text.length > 0 && text.contains(".")) {
            isUser = false;
          }

          // check if it's a real nano address:
          // bool isUser = !text.startsWith("nano_") && !text.startsWith("★");
          if (text.length == 0) {
            setState(() {
              _isUser = false;
              _users = [];
            });
          } else if (isFavorite) {
            var matchedList = await sl.get<DBHelper>().getContactsWithNameLike(SendSheetHelpers.stripPrefixes(text));
            if (matchedList != null) {
              final nicknames = Set();
              matchedList.retainWhere((x) => nicknames.add(x.nickname));
              setState(() {
                _isFavorite = true;
                _users = matchedList;
              });
            }
          } else if (isUser || isDomain) {
            var matchedList = await sl.get<DBHelper>().getUserContactSuggestionsWithNameLike(SendSheetHelpers.stripPrefixes(text));
            if (matchedList != null) {
              setState(() {
                _isFavorite = false;
                _users = matchedList;
              });
            }
          } else {
            setState(() {
              _isUser = false;
              _users = [];
            });
          }
          // Always reset the error message to be less annoying
          if (_addressValidationText?.length > 0) {
            setState(() {
              _addressValidationText = "";
            });
          }
          if (isNano && Address(text).isValid()) {
            _addressFocusNode.unfocus();
            setState(() {
              _addressStyle = AddressStyle.TEXT90;
              _addressValidationText = "";
              _pasteButtonVisible = false;
            });
          } else {
            setState(() {
              _addressStyle = AddressStyle.TEXT60;
            });
          }

          if ((isUser || isFavorite) != _isUser) {
            setState(() {
              _isUser = isUser || isFavorite;
            });
          }
        },
        overrideTextFieldWidget: _addressValidAndUnfocused
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _addressValidAndUnfocused = false;
                  });
                  Future.delayed(Duration(milliseconds: 50), () {
                    FocusScope.of(context).requestFocus(_addressFocusNode);
                  });
                },
                child: UIUtil.threeLineAddressText(context, _addressController.text))
            : null);
  } //************ Enter Address Container Method End ************//
  //*************************************************************//

  //************ Enter Memo Container Method ************//
  //*******************************************************//
  getEnterMemoContainer() {
    double margin = 200;
    if (_addressController.text.startsWith("nano_")) {
      if (_addressController.text.length > 24) {
        margin = 217;
      }
      if (_addressController.text.length > 48) {
        margin = 238;
      }
    }
    return AppTextField(
      topMargin: margin,
      padding: EdgeInsets.zero,
      textAlign: TextAlign.center,
      focusNode: _memoFocusNode,
      controller: _memoController,
      cursorColor: StateContainer.of(context).curTheme.primary,
      inputFormatters: [
        LengthLimitingTextInputFormatter(48),
      ],
      textInputAction: TextInputAction.done,
      maxLines: null,
      autocorrect: false,
      hintText: _memoHint ?? AppLocalization.of(context).enterMemo,
      fadeSuffixOnCondition: true,
      style: TextStyle(
        // fontWeight: FontWeight.w700,
        // fontSize: 16.0,
        // color: StateContainer.of(context).curTheme.primary,
        // fontFamily: 'NunitoSans',
        color: StateContainer.of(context).curTheme.text60,
        fontSize: AppFontSizes.small,
        height: 1.5,
        fontWeight: FontWeight.w100,
        fontFamily: 'OverpassMono',
      ),
      onChanged: (text) {
        // nothing for now
      },
    );
  } //************ Enter Memo Container Method End ************//
  //*************************************************************//
}
