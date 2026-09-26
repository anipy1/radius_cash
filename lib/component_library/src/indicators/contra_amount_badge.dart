import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/tone.dart';
import 'contra_badge.dart';

/// A money amount as a filled badge: whole units when there are no cents,
/// two decimals otherwise, in the current locale's digit style.
class ContraAmountBadge extends StatelessWidget {
  const ContraAmountBadge({
    required this.cents,
    required this.symbol,
    this.tone = Tone.success,
    super.key,
  });

  final int cents;
  final String symbol;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final text = NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      symbol: symbol,
      decimalDigits: cents % 100 == 0 ? 0 : 2,
    ).format(cents / 100);
    return ContraBadge(label: text, tone: tone, filled: true);
  }
}
