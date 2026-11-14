// WIDGETS: small reusable UI pieces. They only display what they are given.

import 'package:flutter/material.dart';

/// An information banner, e.g. "Usage data unavailable", with an optional
/// button.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(title),
              subtitle: Text(body),
            ),
            if (label != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: TextButton(onPressed: onAction, child: Text(label)),
              ),
          ],
        ),
      ),
    );
  }
}
