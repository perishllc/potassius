import 'package:flutter/material.dart';
import 'package:nautilus_wallet_flutter/appstate_container.dart';

// ignore: must_be_immutable
class ListGradient extends StatefulWidget {
  ListGradient({required this.height, this.top, this.begin, this.end, this.alignment, required this.color});

  final double height;
  bool? top;
  AlignmentGeometry? begin;
  AlignmentGeometry? end;
  AlignmentGeometry? alignment;
  // final List<Color> colors;
  final Color color;

  @override
  State<StatefulWidget> createState() {
    return ListGradientState();
  }
}

class ListGradientState extends State<ListGradient> {
  @override
  Widget build(BuildContext context) {
    late AlignmentGeometry begin;
    late AlignmentGeometry end;
    late AlignmentGeometry alignment;

    if (widget.top == true) {
      begin = AlignmentDirectional.topCenter;
      end = AlignmentDirectional.bottomCenter;
      alignment = AlignmentDirectional.topCenter;
    } else if (widget.top == false) {
      begin = AlignmentDirectional.bottomCenter;
      end = AlignmentDirectional.topCenter;
      alignment = AlignmentDirectional.bottomCenter;
    } else {
      begin = widget.begin!;
      end = widget.end!;
      alignment = widget.alignment!;
    }

    final List<Color> colors = <Color>[widget.color, widget.color.withOpacity(0)];

    return Align(
      alignment: alignment,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // colors: <Color>[
            //   StateContainer.of(context).curTheme.background00!,
            //   StateContainer.of(context).curTheme.background!
            // ],
            colors: colors,
            // begin: const AlignmentDirectional(0.5, 1.0),
            // end: const AlignmentDirectional(0.5, -1.0),
            begin: begin,
            end: end,
          ),
        ),
      ),
    );
  }
}
