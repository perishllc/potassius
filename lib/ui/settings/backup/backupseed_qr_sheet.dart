import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/dimens.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/ui/receive/share_card.dart';
import 'package:wallet_flutter/ui/util/handlebars.dart';
import 'package:wallet_flutter/ui/widgets/buttons.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class BackupSeedQRSheet extends StatefulWidget {
  const BackupSeedQRSheet({required this.data, required this.qrWidget}) : super();
  final Widget? qrWidget;
  final String data;

  @override
  // ignore: library_private_types_in_public_api
  _BackupSeedQRSheetState createState() => _BackupSeedQRSheetState();
}

class _BackupSeedQRSheetState extends State<BackupSeedQRSheet> {
  GlobalKey? shareCardKey;
  ByteData? shareImageData;
  // Address copied items
  // Current state references
  bool _showShareCard = false;
  late bool _addressCopied;
  // Timer reference so we can cancel repeated events
  Timer? _addressCopiedTimer;

  FocusNode? _sendAmountFocusNode;
  String? _rawAmount;
  TextEditingController? _sendAmountController;
  bool _localCurrencyMode = false;
  String _amountValidationText = "";
  String? _amountHint = "";
  String _lastLocalCurrencyAmount = "";
  String _lastCryptoAmount = "";

  Widget? qrWidget;

  Future<Uint8List?> _capturePng() async {
    if (shareCardKey != null && shareCardKey!.currentContext != null) {
      final RenderRepaintBoundary boundary = shareCardKey!.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 5.0);
      final ByteData byteData = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return byteData.buffer.asUint8List();
    } else {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Set initial state of copy button
    _addressCopied = false;
    // Create our SVG-heavy things in the constructor because they are slower operations
    // Share card initialization
    shareCardKey = GlobalKey();
    _showShareCard = false;

    _sendAmountFocusNode = FocusNode();
    _sendAmountController = TextEditingController();
    qrWidget = widget.qrWidget;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        minimum: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.035),
        child: GestureDetector(
            onTap: () {
              // Clear focus of our fields when tapped in this empty space
              _sendAmountFocusNode!.unfocus();
            },
            child: Column(
              children: <Widget>[
                // A row for the address text and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    //Empty SizedBox
                    const SizedBox(
                      width: 60,
                      height: 60,
                    ),
                    Column(
                      children: <Widget>[
                        Handlebars.horizontal(
                          context,
                          width: MediaQuery.of(context).size.width * 0.15,
                        ),
                      ],
                    ),
                    //Empty SizedBox
                    const SizedBox(
                      width: 60,
                      height: 60,
                    ),
                  ],
                ),
                // QR which takes all the available space left from the buttons & address text
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 20, bottom: 28, start: 20, end: 20),
                    child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                      final double availableWidth = constraints.maxWidth;
                      final double availableHeight = (StateContainer.of(context).wallet?.username != null)
                          ? (constraints.maxHeight - 70)
                          : constraints.maxHeight;
                      const double widthDivideFactor = 1.3;
                      final double computedMaxSize = math.min(availableWidth / widthDivideFactor, availableHeight);
                      return Center(
                        child: Stack(
                          children: <Widget>[
                            if (_showShareCard)
                              Container(
                                alignment: AlignmentDirectional.center,
                                child: AppShareCard(
                                  shareCardKey,
                                  Center(
                                    child: Transform.translate(
                                      offset: Offset.zero,
                                      child: ClipOval(
                                        child: Container(
                                          color: Colors.white,
                                          height: computedMaxSize,
                                          width: computedMaxSize,
                                          child: qrWidget,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Image(image: AssetImage("assets/logo.png")),
                                ),
                              ),
                            // This is for hiding the share card
                            Center(
                              child: Container(
                                width: 260,
                                height: 150,
                                color: StateContainer.of(context).curTheme.backgroundDark,
                              ),
                            ),
                            // Background/border part the QR
                            // Center(
                            //   child: SizedBox(
                            //     width: computedMaxSize / 1.07,
                            //     height: computedMaxSize / 1.07,
                            //     child: SvgPicture.asset('legacy_assets/QR.svg'),
                            //   ),
                            // ),

                            // Background/border part the QR:
                            Center(
                              child: ClipOval(
                                child: Container(
                                  color: Colors.white,
                                  height: computedMaxSize,
                                  width: computedMaxSize,
                                  child: qrWidget,
                                ),
                              ),
                            ),

                            // Actual QR part of the QR
                            Center(
                              child: Container(
                                color: Colors.white,
                                padding: EdgeInsets.all(computedMaxSize / 51),
                                height: computedMaxSize / 1.53,
                                width: computedMaxSize / 1.53,
                                child: qrWidget,
                              ),
                            ),

                            // Outer ring
                            Center(
                              child: Container(
                                width: computedMaxSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: StateContainer.of(context).curTheme.primary!, width: computedMaxSize / 90),
                                ),
                              ),
                            ),
                            // Logo Background White
                            Center(
                              child: Container(
                                width: computedMaxSize / 5.5,
                                height: computedMaxSize / 5.5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Logo Background Primary
                            Center(
                              child: Container(
                                width: computedMaxSize / 6.5,
                                height: computedMaxSize / 6.5,
                                decoration: const BoxDecoration(
                                  color: /*StateContainer.of(context).curTheme.primary*/ Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Center(
                              child: SizedBox(
                                height: computedMaxSize / 12,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: SvgPicture.asset("assets/logo.svg",
                                      color: StateContainer.of(context).curTheme.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                //A column with Copy Address and Share Address buttons
                Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AppButton.buildAppButton(
                            context,
                            // Copy Address Button
                            _addressCopied ? AppButtonType.SUCCESS : AppButtonType.PRIMARY,
                            _addressCopied ? Z.of(context).seedCopiedShort : Z.of(context).copySeed,
                            Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.data));
                          setState(() {
                            // Set copied style
                            _addressCopied = true;
                          });
                          if (_addressCopiedTimer != null) {
                            _addressCopiedTimer!.cancel();
                          }
                          _addressCopiedTimer = Timer(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              setState(() {
                                _addressCopied = false;
                              });
                            }
                          });
                        }),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        AppButton.buildAppButton(
                            context,
                            // Share Address Button
                            AppButtonType.PRIMARY_OUTLINE,
                            Z.of(context).close,
                            Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                          Navigator.pop(context);
                        }),
                      ],
                    ),
                    // Row(
                    //   children: <Widget>[
                    //     AppButton.buildAppButton(
                    //         context,
                    //         // Share Address Button
                    //         AppButtonType.PRIMARY_OUTLINE,
                    //         Z.of(context).requestPayment,
                    //         Dimens.BUTTON_BOTTOM_DIMENS,
                    //         disabled: _showShareCard, onPressed: () {
                    //       // do nothing
                    //       // if (request == null) {
                    //       // return;
                    //       // }
                    //       // Sheets.showAppHeightEightSheet(context: context, widget: request);
                    //       // Remove any other screens from stack
                    //       Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));

                    //       // Go to send with address
                    //       Sheets.showAppHeightNineSheet(context: context, widget: RequestSheet());
                    //     }),
                    //   ],
                    // ),
                  ],
                ),
              ],
            )));
  }

  void paintQrCode(String data) {
    final PrettyQr painter = PrettyQr(
      data: data,
      typeNumber: 9,
      errorCorrectLevel: QrErrorCorrectLevel.Q,
      roundEdges: true,
    );
    setState(() {
      qrWidget = SizedBox(width: MediaQuery.of(context).size.width / 2.675, child: painter);
    });
  }
}
