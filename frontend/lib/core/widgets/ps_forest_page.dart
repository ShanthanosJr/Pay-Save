import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// The signature layout: forest gradient behind a header, with a light sheet
/// (rounded top corners) sliding over it and holding the content.
class PsForestPage extends StatelessWidget {
  const PsForestPage({
    super.key,
    required this.header,
    required this.children,
    this.sheetTop,
    this.controller,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 32),
  });

  final Widget header;
  final List<Widget> children;
  final Widget? sheetTop;
  final ScrollController? controller;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: header),
                ),
              ),
            ),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 24, end: 0),
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                builder: (context, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: Column(
                      children: [
                        ?sheetTop,
                        Expanded(
                          child: ListView(
                            controller: controller,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: padding,
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: children,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ?bottom,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
