import '../../core/widgets/ps_status_badge.dart';

// Placeholder circle data until the ledger API lands. Money is minor units.

class SampleMember {
  const SampleMember({
    required this.name,
    required this.turn,
    required this.status,
    this.isOrganizer = false,
    this.isYou = false,
  });

  final String name;
  final int turn;
  final ContributionStatus status;
  final bool isOrganizer;
  final bool isYou;
}

enum EntryKind { contribution, correction }

class SampleEntry {
  const SampleEntry({
    required this.kind,
    required this.reference,
    required this.cycle,
    required this.amountMinor,
    required this.method,
    required this.date,
    required this.status,
    this.corrects,
  });

  final EntryKind kind;
  final String reference;
  final int cycle;
  final int amountMinor;
  final String method; // cash | bank_transfer | mobile_wallet
  final DateTime date;
  final ContributionStatus status;
  final String? corrects;
}

class SampleCircle {
  static const name = 'Friends Seettu';
  static const code = 'RC-021';
  static const contributionMinor = 500000;
  static const currentCycle = 4;
  static const totalCycles = 6;
  static final dueDate = DateTime(2026, 9, 30);
  static const daysLeft = 2;
  static const myTurn = 5;
  static const myStatus = ContributionStatus.due;

  static List<SampleMember> members(String yourName) => [
        const SampleMember(name: 'Kamala Silva', turn: 1, status: ContributionStatus.verified, isOrganizer: true),
        const SampleMember(name: 'Ruwan Perera', turn: 2, status: ContributionStatus.verified),
        const SampleMember(name: 'Fathima Rizwan', turn: 3, status: ContributionStatus.recorded),
        const SampleMember(name: 'Kasun Jayawardena', turn: 4, status: ContributionStatus.verified),
        SampleMember(name: yourName, turn: 5, status: myStatus, isYou: true),
        const SampleMember(name: 'Dilini Fernando', turn: 6, status: ContributionStatus.due),
      ];

  static const recipientName = 'Kasun Jayawardena';

  /// Verified pot per cycle; cycles not yet run are null.
  static const collectedPerCycle = <int?>[3000000, 3000000, 3000000, 1500000, null, null];

  static const verifiedThisCycle = 3;

  static final myEntries = <SampleEntry>[
    SampleEntry(
      kind: EntryKind.contribution,
      reference: 'PS-1038',
      cycle: 3,
      amountMinor: 500000,
      method: 'bank_transfer',
      date: DateTime(2026, 8, 28),
      status: ContributionStatus.verified,
    ),
    SampleEntry(
      kind: EntryKind.contribution,
      reference: 'PS-1025',
      cycle: 2,
      amountMinor: 500000,
      method: 'mobile_wallet',
      date: DateTime(2026, 7, 29),
      status: ContributionStatus.verified,
    ),
    SampleEntry(
      kind: EntryKind.correction,
      reference: 'PS-1024',
      cycle: 2,
      amountMinor: -450000,
      method: 'mobile_wallet',
      date: DateTime(2026, 7, 29),
      status: ContributionStatus.verified,
      corrects: 'PS-1021',
    ),
    SampleEntry(
      kind: EntryKind.contribution,
      reference: 'PS-1021',
      cycle: 2,
      amountMinor: 450000,
      method: 'mobile_wallet',
      date: DateTime(2026, 7, 28),
      status: ContributionStatus.verified,
      corrects: null,
    ),
    SampleEntry(
      kind: EntryKind.contribution,
      reference: 'PS-1009',
      cycle: 1,
      amountMinor: 500000,
      method: 'cash',
      date: DateTime(2026, 6, 27),
      status: ContributionStatus.verified,
    ),
  ];

  /// Entries that were later reversed by a correction.
  static const correctedRefs = {'PS-1021'};
}
