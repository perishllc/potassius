import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wallet_flutter/appstate_container.dart';

/// TextField button
class TextFieldButton extends StatelessWidget {
  const TextFieldButton({this.icon, this.onPressed, this.widget, this.padding});

  final IconData? icon;
  final Function? onPressed;
  final Widget? widget;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 48,
        width: 48,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: StateContainer.of(context).curTheme.text30,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200.0)),
            padding: padding ?? const EdgeInsets.all(14.0),
            // highlightColor: StateContainer.of(context).curTheme.text15,
            // splashColor: StateContainer.of(context).curTheme.primary30,
          ),
          onPressed: () {
            onPressed != null ? onPressed!() : null;
          },
          child: widget ?? Icon(icon, size: 20, color: StateContainer.of(context).curTheme.primary),
        ));
  }
}

/// A widget for our custom textfields
class AppTextField extends StatefulWidget {
  const AppTextField(
      {this.focusNode,
      this.controller,
      this.cursorColor,
      this.inputFormatters,
      this.textInputAction,
      this.hintText,
      this.prefixButton,
      this.suffixButton,
      this.fadePrefixOnCondition,
      this.prefixShowFirstCondition,
      this.fadeSuffixOnCondition,
      this.suffixShowFirstCondition,
      this.overrideTextFieldWidget,
      this.keyboardType,
      this.onSubmitted,
      this.onChanged,
      this.style,
      this.leftMargin,
      this.rightMargin,
      this.obscureText = false,
      this.textAlign = TextAlign.center,
      this.keyboardAppearance = Brightness.dark,
      this.autocorrect = true,
      this.maxLines = 1,
      this.padding = EdgeInsets.zero,
      this.buttonFadeDurationMs = 100,
      this.topMargin = 0,
      this.bottomMargin = 0,
      this.autofocus = false});
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final Color? cursorColor;
  final Brightness keyboardAppearance;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final bool autocorrect;
  final String? hintText;
  final Widget? prefixButton;
  final Widget? suffixButton;
  final bool? fadePrefixOnCondition;
  final bool? prefixShowFirstCondition;
  final bool? fadeSuffixOnCondition;
  final bool? suffixShowFirstCondition;
  final EdgeInsetsGeometry padding;
  final Widget? overrideTextFieldWidget;
  final int buttonFadeDurationMs;
  final TextInputType? keyboardType;
  final Function? onSubmitted;
  final Function? onChanged;
  final double topMargin;
  final double bottomMargin;
  final double? leftMargin;
  final double? rightMargin;
  final TextStyle? style;
  final bool obscureText;
  final bool autofocus;

  _AppTextFieldState createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(
            left: widget.leftMargin ?? MediaQuery.of(context).size.width * 0.105,
            right: widget.rightMargin ?? MediaQuery.of(context).size.width * 0.105,
            top: widget.topMargin,
            bottom: widget.bottomMargin),
        padding: widget.padding,
        width: double.infinity,
        decoration: BoxDecoration(
          color: StateContainer.of(context).curTheme.backgroundDarkest,
          borderRadius: BorderRadius.circular(25),
        ),
        child: widget.overrideTextFieldWidget ??
            Stack(alignment: AlignmentDirectional.center, children: <Widget>[
              TextField(
                  // User defined fields
                  textAlign: widget.textAlign,
                  keyboardAppearance: widget.keyboardAppearance,
                  autocorrect: widget.autocorrect,
                  maxLines: widget.maxLines,
                  focusNode: widget.focusNode,
                  controller: widget.controller,
                  cursorColor: widget.cursorColor ?? StateContainer.of(context).curTheme.primary,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: widget.textInputAction,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText,
                  autofocus: widget.autofocus,
                  onSubmitted: widget.onSubmitted != null
                      ? widget.onSubmitted as void Function(String)?
                      : (text) {
                          if (widget.textInputAction == TextInputAction.done) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                  onChanged: widget.onChanged as void Function(String)?,
                  // Style
                  style: widget.style,
                  // Input decoration
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      // Hint
                      hintText: widget.hintText ?? "",
                      hintStyle: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w100,
                        fontFamily: "NunitoSans",
                        color: StateContainer.of(context).curTheme.text60,
                      ),
                      // First button
                      prefixIcon: widget.prefixButton == null
                          ? const SizedBox(width: 0, height: 0)
                          : const SizedBox(width: 48, height: 48),
                      suffixIcon: widget.suffixButton == null
                          ? const SizedBox(width: 0, height: 0)
                          : const SizedBox(width: 48, height: 48))),
              // Buttons
              Column(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    if (widget.fadePrefixOnCondition != null && widget.prefixButton != null)
                      AnimatedCrossFade(
                        duration: Duration(milliseconds: widget.buttonFadeDurationMs),
                        firstChild: widget.prefixButton!,
                        secondChild: const SizedBox(height: 48, width: 48),
                        crossFadeState:
                            widget.prefixShowFirstCondition! ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      )
                    else
                      widget.prefixButton != null ? widget.prefixButton! : const SizedBox(),
                    // Second (suffix) button
                    if (widget.fadeSuffixOnCondition != null && widget.suffixButton != null)
                      AnimatedCrossFade(
                        duration: Duration(milliseconds: widget.buttonFadeDurationMs),
                        firstChild: widget.suffixButton!,
                        secondChild: const SizedBox(height: 48, width: 48),
                        crossFadeState:
                            widget.suffixShowFirstCondition! ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      )
                    else
                      widget.suffixButton != null ? widget.suffixButton! : const SizedBox()
                  ])
                ],
              )
            ]));
  }
}
