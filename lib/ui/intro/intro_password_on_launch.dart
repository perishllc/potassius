import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';
import 'package:wallet_flutter/app_icons.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/dimens.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/localize.dart';
import 'package:wallet_flutter/model/db/appdb.dart';
import 'package:wallet_flutter/model/vault.dart';
import 'package:wallet_flutter/service_locator.dart';
import 'package:wallet_flutter/styles.dart';
import 'package:wallet_flutter/ui/widgets/buttons.dart';
import 'package:wallet_flutter/ui/widgets/security.dart';
import 'package:wallet_flutter/util/nanoutil.dart';
import 'package:wallet_flutter/util/sharedprefsutil.dart';

class IntroPasswordOnLaunch extends StatefulWidget {

  const IntroPasswordOnLaunch({this.seed});
  final String? seed;
  
  @override
  _IntroPasswordOnLaunchState createState() => _IntroPasswordOnLaunchState();
}

class _IntroPasswordOnLaunchState extends State<IntroPasswordOnLaunch> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => SafeArea(
          minimum: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.035, top: MediaQuery.of(context).size.height * 0.075),
          child: Column(
            children: <Widget>[
              //A widget that holds the header, the paragraph and Back Button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        // Back Button
                        Container(
                          margin: EdgeInsetsDirectional.only(start: smallScreen(context) ? 15 : 20),
                          height: 50,
                          width: 50,
                          child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: StateContainer.of(context).curTheme.text15,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
                                padding: EdgeInsets.zero,
                                // highlightColor: StateContainer.of(context).curTheme.text15,
                                // splashColor: StateContainer.of(context).curTheme.text15,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Icon(AppIcons.back, color: StateContainer.of(context).curTheme.text, size: 24)),
                        ),
                      ],
                    ),
                    // The header
                    Container(
                      margin: EdgeInsetsDirectional.only(
                        start: smallScreen(context) ? 30 : 40,
                        end: smallScreen(context) ? 30 : 40,
                        top: 10,
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      child: AutoSizeText(
                        Z.of(context).requireAPasswordToOpenHeader.replaceAll("%1", NonTranslatable.appName),
                        maxLines: 3,
                        stepGranularity: 0.5,
                        style: AppStyles.textStyleHeaderColored(context),
                      ),
                    ),
                    // The paragraph
                    Container(
                      margin: EdgeInsetsDirectional.only(start: smallScreen(context) ? 30 : 40, end: smallScreen(context) ? 30 : 40, top: 16.0),
                      child: AutoSizeText(
                        Z.of(context).createPasswordFirstParagraph,
                        style: AppStyles.textStyleParagraph(context),
                        maxLines: 5,
                        stepGranularity: 0.5,
                      ),
                    ),
                    Container(
                      margin: EdgeInsetsDirectional.only(start: smallScreen(context) ? 30 : 40, end: smallScreen(context) ? 30 : 40, top: 8),
                      child: AutoSizeText(
                        Z.of(context).createPasswordSecondParagraph,
                        style: AppStyles.textStyleParagraphPrimary(context),
                        maxLines: 4,
                        stepGranularity: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              //A column with "Skip" and "Yes" buttons
              Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // Skip Button
                      AppButton.buildAppButton(context, AppButtonType.PRIMARY, Z.of(context).noSkipButton, Dimens.BUTTON_TOP_DIMENS,
                          onPressed: () async {
                        if (widget.seed != null) {
                          await sl.get<Vault>().setSeed(widget.seed);
                          await sl.get<DBHelper>().dropAccounts();
                          if (!mounted) return;
                          await NanoUtil().loginAccount(widget.seed, context);
                          // StateContainer.of(context).requestUpdate();
                          final String? pin = await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
                            return PinScreen(
                              PinOverlayType.NEW_PIN,
                            );
                          }));
                          if (pin != null && pin.length > 5) {
                            _pinEnteredCallback(pin);
                          }
                        } else {
                          // Update wallet
                          await sl.get<Vault>().setSeed(NanoSeeds.generateSeed());
                          if (!mounted) return;
                          final String seed = await StateContainer.of(context).getSeed();
                          if (!mounted) return;
                          await NanoUtil().loginAccount(seed, context);
                          if (!mounted) return;
                          Navigator.of(context).pushNamed('/intro_backup_safety');
                        }
                      }),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      // Yes BUTTON
                      AppButton.buildAppButton(context, AppButtonType.PRIMARY_OUTLINE, Z.of(context).yesButton, Dimens.BUTTON_BOTTOM_DIMENS,
                          onPressed: () {
                        Navigator.of(context).pushNamed('/intro_password', arguments: widget.seed);
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pinEnteredCallback(String pin) async {
    await sl.get<Vault>().writePin(pin);
    final PriceConversion conversion = await sl.get<SharedPrefsUtil>().getPriceConversion();
    if (!mounted) return;
    StateContainer.of(context).requestSubscribe();
    // Update wallet
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false, arguments: conversion);
  }
}
