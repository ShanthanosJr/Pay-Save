import 'outbox_store.dart';

/// The browser build is the organizer's desk view and is used online; a
/// payment that cannot be sent is kept for this session only.
OutboxStore openOutboxStore() => MemoryOutboxStore();
