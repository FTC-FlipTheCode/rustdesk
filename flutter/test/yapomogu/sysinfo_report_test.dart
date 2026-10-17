import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/yapomogu/sysinfo_collector.dart';

void main() {
  test('parseSysinfoReport keeps the bridge fields with numeric values', () {
    const raw = '{"hostname":"ROMASHKA-PC","os":"Microsoft Windows 10 Pro 10.0.19045",'
        '"cpu":"Intel(R) Core(TM) i5-10400 CPU @ 2.90GHz","cpu_cores":6,'
        '"ram_total_gb":15.9,"ram_used_gb":6.2,'
        '"disks":[{"name":"C","total_gb":237.9,"free_gb":30.1},{"name":"D","total_gb":931,"free_gb":800}],'
        '"ip":"192.168.1.47","last_boot":"2026-10-14T09:12:00","extra":"ignored"}';

    final r = parseSysinfoReport(raw)!;

    expect(r['hostname'], 'ROMASHKA-PC');
    expect(r['cpu_cores'], 6);
    expect(r['ram_total_gb'], 15.9);
    expect(r['disks'], [
      {'name': 'C', 'total_gb': 237.9, 'free_gb': 30.1},
      {'name': 'D', 'total_gb': 931.0, 'free_gb': 800.0},
    ]);
    expect(r.containsKey('extra'), isFalse);
  });

  test('parseSysinfoReport accepts a single disk object and rejects garbage', () {
    final r = parseSysinfoReport('{"hostname":"PC","disks":{"name":"C","total_gb":100,"free_gb":10}}')!;
    expect(r['disks'], [{'name': 'C', 'total_gb': 100.0, 'free_gb': 10.0}]);

    expect(parseSysinfoReport('not json'), isNull);
    expect(parseSysinfoReport(''), isNull);
  });
}
