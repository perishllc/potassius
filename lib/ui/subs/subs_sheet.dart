import 'dart:async';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_cron/easy_cron.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/bus/sub_modified_event.dart';
import 'package:wallet_flutter/dimens.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/model/address.dart';
import 'package:wallet_flutter/model/db/appdb.dart';
import 'package:wallet_flutter/model/db/subscription.dart';
import 'package:wallet_flutter/service_locator.dart';
import 'package:wallet_flutter/styles.dart';
import 'package:wallet_flutter/ui/subs/add_sub_sheet.dart';
import 'package:wallet_flutter/ui/subs/sub_confirm_sheet.dart';
import 'package:wallet_flutter/ui/subs/sub_details_sheet.dart';
import 'package:wallet_flutter/ui/util/formatters.dart';
import 'package:wallet_flutter/ui/util/handlebars.dart';
import 'package:wallet_flutter/ui/widgets/buttons.dart';
import 'package:wallet_flutter/ui/widgets/dialog.dart';
import 'package:wallet_flutter/ui/widgets/draggable_scrollbar.dart';
import 'package:wallet_flutter/ui/widgets/list_gradient.dart';
import 'package:wallet_flutter/ui/widgets/sheet_util.dart';
import 'package:wallet_flutter/ui/widgets/transaction_state_tag.dart';
import 'package:wallet_flutter/util/caseconverter.dart';

class SubsSheet extends StatefulWidget {
  SubsSheet({super.key, required this.subs});

  List<Subscription> subs;

  @override
  SubsSheetState createState() => SubsSheetState();
}

class SubsSheetState extends State<SubsSheet> {
  static const int MAX_ACCOUNTS = 50;
  final GlobalKey expandedKey = GlobalKey();

  bool _addingNode = false;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<SubModifiedEvent>? _subscriptionModifiedSub;
  late bool _nodeIsChanging;

  Future<bool> _onWillPop() async {
    if (_subscriptionModifiedSub != null) {
      _subscriptionModifiedSub!.cancel();
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _registerBus();
    _addingNode = false;
    _nodeIsChanging = false;
  }

  @override
  void dispose() {
    _destroyBus();
    super.dispose();
  }

  void _registerBus() {
    _subscriptionModifiedSub =
        EventTaxiImpl.singleton().registerTo<SubModifiedEvent>().listen((SubModifiedEvent event) {
      if (event.deleted) {
        setState(() {
          widget.subs.removeWhere((Subscription a) => a.id == event.sub!.id);
        });
      } else if (event.created && event.sub != null) {
        setState(() {
          widget.subs.add(event.sub!);
        });
      } else {
        // update subs list:
        // backlog: not very efficient since we'll be reloading everything from disk,
        // but not worth the effort to optimize this imo
        sl.get<DBHelper>().getSubscriptions().then((List<Subscription> subs) {
          setState(() {
            widget.subs = subs;
          });
        });
        // setState(() {
        // widget.subs.removeWhere((Subscription a) => a.id == event.sub!.id);
        // widget.subs.add(event.sub!);
        // widget.subs.sort((Subscription a, Subscription b) => a.id!.compareTo(b.id!));
        // });
      }
    });
  }

  void _destroyBus() {
    if (_subscriptionModifiedSub != null) {
      _subscriptionModifiedSub!.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    // double bottomMargin = 60;
    // // TODO: better calculation of bottom bar height
    // if (Platform.isIOS) {
    //   bottomMargin = 100;
    // }
    return SafeArea(
      minimum: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.035,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: StateContainer.of(context).curTheme.backgroundDark,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      Container(
                        margin: const EdgeInsets.only(top: 15.0),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                        child: Column(
                          children: <Widget>[
                            AutoSizeText(
                              CaseChange.toUpperCase(Z.of(context).subsButton, context),
                              style: AppStyles.textStyleHeader(context),
                              maxLines: 1,
                              stepGranularity: 0.1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: AppDialogs.infoButton(
                      context,
                      () {},
                    ),
                  ),
                ],
              ),

              // A list containing accounts
              Expanded(
                  key: expandedKey,
                  child: Stack(
                    children: <Widget>[
                      if (widget.subs == null)
                        const Center(
                          child: Text("Loading"),
                        )
                      else
                        DraggableScrollbar(
                          controller: _scrollController,
                          scrollbarColor: StateContainer.of(context).curTheme.primary,
                          scrollbarTopMargin: 20.0,
                          scrollbarBottomMargin: 12.0,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            itemCount: widget.subs.length,
                            controller: _scrollController,
                            itemBuilder: (BuildContext context, int index) {
                              return _buildSubListItem(context, widget.subs[index], setState, index);
                            },
                          ),
                        ),

                      // begin: const AlignmentDirectional(0.5, 1.0),
                      // end: const AlignmentDirectional(0.5, -1.0),
                      ListGradient(
                        height: 20,
                        top: true,
                        color: StateContainer.of(context).curTheme.backgroundDark!,
                      ),
                      ListGradient(
                        height: 20,
                        top: false,
                        color: StateContainer.of(context).curTheme.backgroundDark!,
                      ),
                    ],
                  )),
              const SizedBox(
                height: 15,
              ),
              //A row with Add Sub button
              Row(
                children: <Widget>[
                  AppButton.buildAppButton(
                    context,
                    AppButtonType.PRIMARY,
                    Z.of(context).addSubscription,
                    Dimens.BUTTON_TOP_DIMENS,
                    disabled: _addingNode,
                    onPressed: () async {
                      if (!_addingNode) {
                        setState(() {
                          _addingNode = true;
                        });

                        final Subscription? sub = await Sheets.showAppHeightNineSheet(
                          context: context,
                          widget: AddSubSheet(
                            localCurrency: StateContainer.of(context).curCurrency,
                          ),
                        ) as Subscription?;
                        if (!mounted) return;
                        if (sub == null) {
                          setState(() {
                            _addingNode = false;
                          });
                          return;
                        }
                        await Sheets.showAppHeightNineSheet(
                          context: context,
                          widget: SubConfirmSheet(sub: sub),
                        );
                        if (!mounted) return;
                        setState(() {
                          _addingNode = false;
                        });

                        // sl.get<DBHelper>().saveNode(node).then((Node? newNode) {
                        //   if (newNode == null) {
                        //     sl.get<Logger>().d("Error adding node: node was null");
                        //     return;
                        //   }
                        //   widget.nodes.add(newNode);
                        //   setState(() {
                        //     _addingNode = false;
                        //     widget.nodes.sort((Node a, Node b) => a.id!.compareTo(b.id!));
                        //     // Scroll if list is full
                        //     if (expandedKey.currentContext != null) {
                        //       final RenderBox? box = expandedKey.currentContext!.findRenderObject() as RenderBox?;
                        //       if (box == null) return;
                        //       if (widget.nodes.length * 72.0 >= box.size.height) {
                        //         _scrollController.animateTo(
                        //           newNode.id! * 72.0 > _scrollController.position.maxScrollExtent
                        //               ? _scrollController.position.maxScrollExtent + 72.0
                        //               : newNode.id! * 72.0,
                        //           curve: Curves.easeOut,
                        //           duration: const Duration(milliseconds: 200),
                        //         );
                        //       }
                        //     }
                        //   });
                        // });
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  AppButton.buildAppButton(
                    context,
                    AppButtonType.PRIMARY_OUTLINE,
                    Z.of(context).close,
                    Dimens.BUTTON_BOTTOM_DIMENS,
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubListItem(BuildContext context, Subscription sub, StateSetter setState, int index) {
    DateTime nextPaymentTime;
    try {
      nextPaymentTime = UnixCronParser().parse(sub.frequency).next().time;
    } catch (e) {
      nextPaymentTime = DateTime.now();
    }
    Color? subColor = StateContainer.of(context).curTheme.success;

    if (sub.active) {
      subColor = StateContainer.of(context).curTheme.success;
      // if (sub.paid) {
      //   subColor = StateContainer.of(context).curTheme.success;
      // } else {
      //   subColor = StateContainer.of(context).curTheme.warning;
      // }
    } else {
      subColor = StateContainer.of(context).curTheme.error;
      // if (sub.paid) {
      //   subColor = StateContainer.of(context).curTheme.warning;
      // } else {
      //   subColor = StateContainer.of(context).curTheme.error;
      // }
    }

    return Column(
      children: <Widget>[
        Divider(
          height: 2,
          color: StateContainer.of(context).curTheme.text15,
        ),
        Container(
          margin: const EdgeInsets.only(right: 10),
          child: Slidable(
            closeOnScroll: true,
            endActionPane: _getSlideActionsForSub(context, sub, setState),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: StateContainer.of(context).curTheme.text15,
                backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),

              // highlightColor: StateContainer.of(context).curTheme.text15,
              // splashColor: StateContainer.of(context).curTheme.text15,
              // padding: EdgeInsets.all(0.0),
              onPressed: () {
                Sheets.showAppHeightEightSheet(
                  context: context,
                  widget: SubDetailsSheet(sub: sub),
                  animationDurationMs: 175,
                );
              },
              child: SizedBox(
                height: 75,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Icon, Account Name, Address and Amount
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: 65,
                            child: Stack(
                              children: <Widget>[
                                Container(
                                  alignment: Alignment.topCenter,
                                  margin: const EdgeInsetsDirectional.only(top: 8),
                                  child: Icon(
                                    sub.active ? Icons.paid : Icons.money_off,
                                    color: subColor,
                                    size: 30,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsetsDirectional.only(bottom: 8),
                                  alignment: Alignment.bottomCenter,
                                  child: TransactionStateTag(
                                    transactionState:
                                        sub.paid ? TransactionStateOptions.PAID : TransactionStateOptions.UNPAID,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Account name and address

                          Expanded(
                            child: Container(
                              // width: MediaQuery.of(context).size.width - 140,
                              // width: (MediaQuery.of(context).size.width - 200),
                              margin: const EdgeInsetsDirectional.only(start: 20, end: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // Account name
                                  AutoSizeText(
                                    sub.label,
                                    style: TextStyle(
                                      fontFamily: "NunitoSans",
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16.0,
                                      color: StateContainer.of(context).curTheme.text,
                                    ),
                                    minFontSize: 8.0,
                                    stepGranularity: 1,
                                    maxLines: 1,
                                    textAlign: TextAlign.start,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: "${Z.of(context).amount}: ",
                                          style: TextStyle(
                                            fontFamily: "OverpassMono",
                                            fontWeight: FontWeight.w100,
                                            fontSize: AppFontSizes.small,
                                            color: StateContainer.of(context).curTheme.text60,
                                          ),
                                        ),
                                      ),
                                      RichText(
                                        textAlign: TextAlign.start,
                                        text: TextSpan(
                                          text: "",
                                          children: <InlineSpan>[
                                            TextSpan(
                                              text: getThemeAwareRawAccuracy(context, sub.amount_raw),
                                              style: AppStyles.textStyleParagraphPrimary(context),
                                            ),
                                            displayCurrencySymbol(
                                              context,
                                              AppStyles.textStyleParagraphPrimary(context),
                                            ),
                                            TextSpan(
                                              text: getRawAsThemeAwareFormattedAmount(context, sub.amount_raw),
                                              style: AppStyles.textStyleParagraphPrimary(context),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // AutoSizeText(
                                  //   Address(sub.address).getShortString() ?? "",
                                  //   style: TextStyle(
                                  //     fontFamily: "OverpassMono",
                                  //     fontWeight: FontWeight.w100,
                                  //     fontSize: 14.0,
                                  //     color: StateContainer.of(context).curTheme.text60,
                                  //   ),
                                  //   minFontSize: 8.0,
                                  //   stepGranularity: 0.1,
                                  //   maxLines: 1,
                                  // ),

                                  // display next payment time:
                                  if (sub.active)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            text: "${Z.of(context).nextPayment}: ",
                                            style: TextStyle(
                                              fontFamily: "OverpassMono",
                                              fontWeight: FontWeight.w100,
                                              fontSize: AppFontSizes.small,
                                              color: StateContainer.of(context).curTheme.text60,
                                            ),
                                          ),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            text: getCardTime(nextPaymentTime.millisecondsSinceEpoch ~/ 1000),
                                            style: TextStyle(
                                              fontFamily: "OverpassMono",
                                              fontWeight: FontWeight.w100,
                                              fontSize: AppFontSizes.small,
                                              color: StateContainer.of(context).curTheme.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Container(
                                  //   // margin: const EdgeInsetsDirectional.only(start: 10, end: 10),
                                  //   alignment: Alignment.centerLeft,
                                  //   child: TransactionStateTag(
                                  //     transactionState:
                                  //         sub.paid ? TransactionStateOptions.PAID : TransactionStateOptions.UNPAID,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Handlebars.vertical(context),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (index == widget.subs.length - 1)
          Divider(
            height: 2,
            color: StateContainer.of(context).curTheme.text15,
          ),
      ],
    );
  }

  ActionPane _getSlideActionsForSub(BuildContext context, Subscription sub, StateSetter setState) {
    final List<Widget> actions = <Widget>[];

    // actions.add(SlidableAction(
    //     autoClose: false,
    //     borderRadius: BorderRadius.circular(5.0),
    //     backgroundColor: StateContainer.of(context).curTheme.backgroundDark!,
    //     foregroundColor: StateContainer.of(context).curTheme.primary,
    //     icon: Icons.edit,
    //     label: Z.of(context).edit,
    //     onPressed: (BuildContext context) async {
    //       await Future<dynamic>.delayed(const Duration(milliseconds: 250));
    //       if (!mounted) return;
    //       // Sheets.showAppHeightEightSheet(
    //       //   context: context,
    //       //   widget: SubDetailsSheet(sub: sub),
    //       //   animationDurationMs: 175,
    //       // );
    //       await Slidable.of(context)!.close();
    //     }));

    actions.add(
      SlidableAction(
        autoClose: false,
        borderRadius: BorderRadius.circular(5.0),
        backgroundColor: StateContainer.of(context).curTheme.backgroundDark!,
        foregroundColor: StateContainer.of(context).curTheme.error60,
        icon: Icons.delete,
        label: Z.of(context).delete,
        onPressed: (BuildContext context) {
          AppDialogs.showConfirmDialog(context, Z.of(context).deleteSubHeader, Z.of(context).deleteSubConfirmation,
              CaseChange.toUpperCase(Z.of(context).yes, context), () async {
            await Future<dynamic>.delayed(const Duration(milliseconds: 250));
            // Remove account
            await sl.get<DBHelper>().deleteSubscription(sub);
            EventTaxiImpl.singleton().fire(SubModifiedEvent(sub: sub, deleted: true));
            setState(() {
              widget.subs.removeWhere((Subscription acc) => acc.id == sub.id);
            });
            if (!mounted) return;
            await Slidable.of(context)!.close();
          }, cancelText: CaseChange.toUpperCase(Z.of(context).no, context));
        },
      ),
    );

    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: 0.25,
      children: actions,
    );
  }
}
