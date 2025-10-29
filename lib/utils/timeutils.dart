String fmtTime(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final y = t.year.toString();
  final mm = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  return '$y-$mm-$d $h:$m:$s';
}