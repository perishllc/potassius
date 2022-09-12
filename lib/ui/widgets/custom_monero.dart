import 'dart:async';

import 'package:event_taxi/event_taxi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';
import 'package:nautilus_wallet_flutter/appstate_container.dart';
import 'package:nautilus_wallet_flutter/bus/xmr_event.dart';
import 'package:nautilus_wallet_flutter/service_locator.dart';
import 'package:nautilus_wallet_flutter/util/blake2b.dart';
import 'package:nautilus_wallet_flutter/util/sharedprefsutil.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ignore: must_be_immutable
class CustomMonero extends StatefulWidget {
  const CustomMonero();
  @override
  State<StatefulWidget> createState() {
    return CustomMoneroState();
  }
}

// final webViewKey = GlobalKey<CustomMoneroState>();

class CustomMoneroState extends State<CustomMonero> with AutomaticKeepAliveClientMixin<CustomMonero> {
  WebViewController? webViewController;

  StreamSubscription<XMREvent>? _xmrSub;

  String? walletData;

  Future<void> initWallet() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 3500));
    walletData = await sl.get<SharedPrefsUtil>().getXmrWalletData();
    if (walletData != null) {
      webViewController?.runJavascript("window.walletData = '$walletData'; window.action = 'xmr_init';");
    } else {
      webViewController?.runJavascript("window.action = 'xmr_init';");
    }
  }

  @override
  void initState() {
    super.initState();
    _registerBus();

    // get xmr wallet data:
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      initWallet();
    });
  }

  @override
  void dispose() {
    _destroyBus();
    super.dispose();
  }

  void _registerBus() {
    // xmr:
    _xmrSub = EventTaxiImpl.singleton().registerTo<XMREvent>().listen((XMREvent event) async {
      if (event.type == "xmr_reload") {
        webViewController?.reload();
        initWallet();
      }
      if (event.type == "xmr_send" || event.type == "xmr_get_fee") {
        // webViewController?.reload();
        final List<String> msgs = event.message.split(":");
        final String address = msgs[0];
        final String amount = msgs[1];
        webViewController
            ?.runJavascript("window.action = '${event.type}'; window.address = '$address'; window.amount = '$amount';");
      }
      if (event.type == "update_wallet_data") {
        walletData = event.message;
        if (walletData != null) {
          sl.get<SharedPrefsUtil>().setXmrWalletData(walletData!);
        }
      }
    });
  }

  void _destroyBus() {
    if (_xmrSub != null) {
      _xmrSub!.cancel();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 100,

      // margin: const EdgeInsets.all(30),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
        child: FutureBuilder<String>(
          future: StateContainer.of(context).getSeed(),
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final String hashedSeed =
                  NanoHelpers.byteToHex(blake2b(NanoHelpers.hexToBytes(snapshot.data as String))).substring(0, 64);
              String url = "http://localhost:8080/assets/xmr/index.html#s=$hashedSeed";

              if (kDebugMode) {
                url = "http://142.93.244.88:8080/#s=$hashedSeed";
              }
              final int? restoreHeight = StateContainer.of(context).xmrRestoreHeight;
              if (restoreHeight != null && restoreHeight > 0) {
                url += "&h=$restoreHeight";
              }
              return WebView(
                initialUrl: url,
                javascriptMode: JavascriptMode.unrestricted,
                debuggingEnabled: !kReleaseMode,
                gestureNavigationEnabled: true,
                zoomEnabled: false,
                javascriptChannels: {
                  JavascriptChannel(
                      name: "XMR",
                      onMessageReceived: (JavascriptMessage message) {
                        final String messageString = message.message;
                        final String type = messageString.substring(0, messageString.indexOf(":"));
                        final String eventMessage = messageString.substring(messageString.indexOf(":") + 1);
                        print("type: $type - eventMessage: $eventMessage");
                        EventTaxiImpl.singleton().fire(XMREvent(type: type, message: eventMessage));
                      }),
                  JavascriptChannel(
                      name: "CloseWebView",
                      onMessageReceived: (JavascriptMessage message) {
                        Navigator.of(context).pop();
                      })
                },
                onWebViewCreated: (WebViewController w) {
                  webViewController = w;
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
