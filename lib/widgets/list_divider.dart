import 'package:flutter/material.dart';

class ListDivider extends StatelessWidget {
  const ListDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Divider(
      color: theme.scaffoldBackgroundColor,
      thickness: 2,
      height: 2,
    );
  }
}
