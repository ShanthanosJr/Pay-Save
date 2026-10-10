import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'outbox_db.dart';
import 'outbox_store.dart';

/// SQLite file in the app's private documents folder.
OutboxStore openOutboxStore() => DriftOutboxStore(OutboxDatabase(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'pay_and_save_outbox.sqlite')));
    })));
