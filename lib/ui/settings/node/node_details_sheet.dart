import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';
import 'package:wallet_flutter/app_icons.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/bus/node_modified_event.dart';
import 'package:wallet_flutter/dimens.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/model/db/appdb.dart';
import 'package:wallet_flutter/model/db/node.dart';
import 'package:wallet_flutter/service_locator.dart';
import 'package:wallet_flutter/styles.dart';
import 'package:wallet_flutter/ui/util/handlebars.dart';
import 'package:wallet_flutter/ui/widgets/app_text_field.dart';
import 'package:wallet_flutter/ui/widgets/buttons.dart';
import 'package:wallet_flutter/ui/widgets/dialog.dart';
import 'package:wallet_flutter/ui/widgets/sheets.dart';
import 'package:wallet_flutter/ui/widgets/tap_outside_unfocus.dart';
import 'package:wallet_flutter/util/caseconverter.dart';

class NodeDetailsSheet extends StatefulWidget {
  NodeDetailsSheet({required this.node}) : super();
  Node node;

  @override
  NodeDetailsSheetState createState() => NodeDetailsSheetState();
}

class NodeDetailsSheetState extends State<NodeDetailsSheet> {
  String? originalName;
  TextEditingController? _nameController;
  FocusNode? _nameFocusNode;
  late bool deleted;
  // Address copied or not
  late bool _addressCopied;
  // Timer reference so we can cancel repeated events
  Timer? _addressCopiedTimer;

  Future<bool> _onWillPop() async {
    // Update name if changed and valid
    if (originalName != _nameController!.text && _nameController!.text.trim().isNotEmpty && !deleted) {
      sl.get<DBHelper>().changeNodeName(widget.node, _nameController!.text);
      widget.node.name = _nameController!.text;
      EventTaxiImpl.singleton().fire(NodeModifiedEvent(node: widget.node));
    }
    return true;
  }

  void initState() {
    super.initState();
    originalName = widget.node.name;
  }

  @override
  Widget build(BuildContext context) {
    _addressCopied = false;
    _nameController = TextEditingController(text: widget.node.name);
    _nameFocusNode = FocusNode();
    return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
      return WillPopScope(
          onWillPop: _onWillPop,
          child: TapOutsideUnfocus(
              child: SafeArea(
                  minimum: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.035),
                  child: Column(
                    children: <Widget>[
                      Handlebars.horizontal(context),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Trashcan Button
                          Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsetsDirectional.only(top: 18.0, start: 10.0),
                              child: widget.node.id == 0
                                  ? const SizedBox()
                                  : TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: StateContainer.of(context).curTheme.text15,
                                        padding: const EdgeInsets.all(13.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                                        tapTargetSize: MaterialTapTargetSize.padded,
                                        // highlightColor: StateContainer.of(context).curTheme.text15,
                                        // splashColor: StateContainer.of(context).curTheme.text15,
                                      ),
                                      onPressed: () {
                                        AppDialogs.showConfirmDialog(
                                            context,
                                            Z.of(context).hideAccountHeader,
                                            Z.of(context).removeAccountText.replaceAll("%1", Z.of(context).addNode),
                                            CaseChange.toUpperCase(Z.of(context).yes, context), () {
                                          // Remove account
                                          deleted = true;
                                          sl.get<DBHelper>().deleteNode(widget.node).then((int id) {
                                            EventTaxiImpl.singleton()
                                                .fire(NodeModifiedEvent(node: widget.node, deleted: true));
                                            Navigator.of(context).pop();
                                          });
                                        }, cancelText: CaseChange.toUpperCase(Z.of(context).no, context));
                                      },
                                      child: Icon(AppIcons.trashcan,
                                          size: 24, color: StateContainer.of(context).curTheme.text),
                                    )),
                          // The header of the sheet
                          Container(
                            margin: const EdgeInsets.only(top: 25.0),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                            child: Column(
                              children: <Widget>[
                                AutoSizeText(
                                  CaseChange.toUpperCase(Z.of(context).node, context),
                                  style: AppStyles.textStyleHeader(context),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  stepGranularity: 0.1,
                                ),
                              ],
                            ),
                          ),
                          // Search Button
                          const SizedBox(height: 50, width: 50),
                        ],
                      ),
                      // Address Text
                      // Container(
                      //   margin: const EdgeInsets.only(top: 10.0),
                      //   child: account.address != null
                      //       ? UIUtil.threeLineAddressText(context, account.address!,
                      //           type: ThreeLineAddressTextType.PRIMARY60)
                      //       : account.selected
                      //           ? UIUtil.threeLineAddressText(
                      //               context, StateContainer.of(context).wallet!.address!,
                      //               type: ThreeLineAddressTextType.PRIMARY60)
                      //           : const SizedBox(),
                      // ),
                      // The main container that holds Contact Name and Contact Address
                      Expanded(
                        child: KeyboardAvoider(
                            duration: Duration.zero,
                            autoScroll: true,
                            focusPadding: 40,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                              AppTextField(
                                topMargin: MediaQuery.of(context).size.width * 0.14,
                                rightMargin: MediaQuery.of(context).size.width * 0.105,
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                keyboardType: TextInputType.text,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.0,
                                  color: StateContainer.of(context).curTheme.primary,
                                  fontFamily: "NunitoSans",
                                ),
                              ),
                            ])),
                      ),
                      Column(
                        children: <Widget>[
                          // Row(
                          //   children: <Widget>[
                          //     AppButton.buildAppButton(
                          //         context,
                          //         // Share Address Button
                          //         _addressCopied ? AppButtonType.SUCCESS : AppButtonType.PRIMARY,
                          //         _addressCopied
                          //             ? Z.of(context).addressCopied
                          //             : Z.of(context).copyAddress,
                          //         Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                          //       Clipboard.setData(ClipboardData(text: node.address));
                          //       setState(() {
                          //         // Set copied style
                          //         _addressCopied = true;
                          //       });
                          //       if (_addressCopiedTimer != null) {
                          //         _addressCopiedTimer!.cancel();
                          //       }
                          //       _addressCopiedTimer = Timer(const Duration(milliseconds: 800), () {
                          //         setState(() {
                          //           _addressCopied = false;
                          //         });
                          //       });
                          //     }),
                          //   ],
                          // ),
                          Row(
                            children: <Widget>[
                              // Close Button
                              AppButton.buildAppButton(context, AppButtonType.PRIMARY_OUTLINE, Z.of(context).close,
                                  Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                                Navigator.pop(context);
                              }),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ))));
    });
    ;
  }
}
