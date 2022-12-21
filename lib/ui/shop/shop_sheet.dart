import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wallet_flutter/app_icons.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/localize.dart';
import 'package:wallet_flutter/model/available_currency.dart';
import 'package:wallet_flutter/styles.dart';
import 'package:wallet_flutter/ui/shop/use_card.dart';
import 'package:wallet_flutter/ui/util/ui_util.dart';
import 'package:wallet_flutter/ui/widgets/draggable_scrollbar.dart';

class ShopSheet extends StatefulWidget {
  const ShopSheet({required this.localCurrency}) : super();

  final AvailableCurrency localCurrency;

  @override
  ShopSheetState createState() => ShopSheetState();
}

class ShopSheetState extends State<ShopSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double bottomMargin = 60;
    // TODO: better calculation of bottom bar height
    if (Platform.isIOS) {
      bottomMargin = 100;
    }
    return SafeArea(
      minimum: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.05, bottom: bottomMargin),
      child: Container(
        // padding: const EdgeInsets.only(left: 20, right: 20),
        decoration: BoxDecoration(
          color: StateContainer.of(context).curTheme.backgroundDark,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
        ),
        child: DraggableScrollbar(
          controller: _scrollController,
          scrollbarColor: StateContainer.of(context).curTheme.primary,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // products title section:
                Container(
                  margin: const EdgeInsets.only(top: 15, bottom: 20),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                  child: Column(
                    children: <Widget>[
                      AutoSizeText(
                        Z.of(context).useNano,
                        style: AppStyles.textStyleHeader(context),
                        maxLines: 1,
                        stepGranularity: 0.1,
                      ),
                    ],
                  ),
                ),

                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     UseCard(
                //       image: "assets/logos/luckynano.png",
                //       title: NonTranslatable.wenano,
                //       onPress: () async {
                //         await UIUtil.showChromeSafariWebview(context, "https://luckynano.com");
                //       },
                //     ),
                //     UseCard(
                //       image: "assets/logos/playnano.png",
                //       title: NonTranslatable.cryptovision,
                //       onPress: () async {
                //         await UIUtil.showChromeSafariWebview(context, "https://playnano.online/?ref=nautilus");
                //       },
                //     ),
                //   ],
                // ),

                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      Text(
                        Z.of(context).getNano,
                        style: AppStyles.textStyleHeader2Colored(context),
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      icon: AppIcons.content_copy,
                      title: Z.of(context).copyWalletAddressToClipboard,
                      onPress: () async {
                        Clipboard.setData(ClipboardData(text: StateContainer.of(context).wallet!.address));
                        UIUtil.showSnackbar(Z.of(context).addressCopied, context, durationMs: 1500);
                      },
                    ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      image: "assets/logos/onramper.png",
                      title: NonTranslatable.onramper,
                      onPress: () async {
                        final String url =
                            "https://widget.onramper.com?apiKey=${dotenv.env["ONRAMPER_API_KEY"]!}&color=4080D7&onlyCryptos=NANO&defaultCrypto=NANO&darkMode=${StateContainer.of(context).curTheme.brightness == Brightness.dark}";
                        await UIUtil.showChromeSafariWebview(context, url);
                      },
                    ),
                    UseCard(
                      image: "assets/logos/nanocafe.png",
                      title: NonTranslatable.nanocafe,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://nanocafe.cc/faucet");
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      Text(
                        Z.of(context).spendNano,
                        style: AppStyles.textStyleHeader2Colored(context),
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      image: "assets/logos/redeemforme.png",
                      title: NonTranslatable.redeemforme,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://redeemfor.me");
                      },
                    ),
                  ],
                ),

                // Padding(
                //   padding: const EdgeInsets.only(left: 20),
                //   child: Row(
                //     children: [
                //       Text(
                //         Z.of(context).exchangeNano,
                //         style: AppStyles.textStyleHeader2Colored(context),
                //       ),
                //     ],
                //   ),
                // ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      image: "assets/logos/luckynano.png",
                      title: NonTranslatable.luckynano,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://luckynano.com");
                      },
                    ),
                    UseCard(
                      image: "assets/logos/playnano.png",
                      title: NonTranslatable.playnano,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://playnano.online/?ref=nautilus");
                      },
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      Text(
                        Z.of(context).exchangeNano,
                        style: AppStyles.textStyleHeader2Colored(context),
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      image: "assets/logos/nanswap.png",
                      title: NonTranslatable.nanswap,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://nanswap.com/?ref=nautilus");
                      },
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      Text(
                        Z.of(context).useNano,
                        style: AppStyles.textStyleHeader2Colored(context),
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UseCard(
                      image: "assets/logos/wenano.png",
                      title: NonTranslatable.wenano,
                      onPress: () async {
                        await UIUtil.showChromeSafariWebview(context, "https://wenano.net");
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
