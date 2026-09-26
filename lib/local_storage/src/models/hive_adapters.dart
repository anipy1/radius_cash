// Uint8List is needed by the generated part, which shares these imports.
import 'dart:typed_data'; // ignore: unused_import

import 'package:hive_ce/hive.dart';

import 'bounty_cm.dart';
import 'claim_cm.dart';
import 'witness_cm.dart';

part 'hive_adapters.g.dart';

/// Type ids and field indices are pinned in hive_adapters.g.yaml. Never
/// renumber; a phone that cached a bounty under the old numbering would read
/// garbage.
@GenerateAdapters([
  AdapterSpec<BountyCM>(),
  AdapterSpec<ClaimCM>(),
  AdapterSpec<WitnessCM>(),
])
// ignore: unused_element
void _() {}
