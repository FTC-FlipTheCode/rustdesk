import 'dart:convert';
import 'dart:io';

// One PowerShell call, UTF-8 JSON, numbers not formatted text: what the bridge stores.
const _reportScript = r'''
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$cs  = Get-CimInstance Win32_ComputerSystem
$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$disks = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  [pscustomobject]@{ name = $_.DeviceID.TrimEnd(':'); total_gb = [math]::Round($_.Size / 1GB, 1); free_gb = [math]::Round($_.FreeSpace / 1GB, 1) } })
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.254*' } | Select-Object -First 1).IPAddress
[pscustomobject]@{
  hostname = $cs.Name; os = "$($os.Caption) $($os.Version)"; cpu = "$($cpu.Name)".Trim(); cpu_cores = [int]$cpu.NumberOfCores
  ram_total_gb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  ram_used_gb = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
  disks = $disks; ip = "$ip"; last_boot = $os.LastBootUpTime.ToString('s')
} | ConvertTo-Json -Depth 3 -Compress
''';

String _str(Object? v, int max) {
  final s = (v ?? '').toString().trim();
  return s.length > max ? s.substring(0, max) : s;
}

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// Bridge-shaped report from the PowerShell JSON, or null if it is not usable.
Map<String, dynamic>? parseSysinfoReport(String raw) {
  Object? data;
  try {
    data = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (data is! Map) return null;
  final rawDisks = data['disks'];
  final disks = (rawDisks is List ? rawDisks : rawDisks is Map ? [rawDisks] : const [])
      .whereType<Map>()
      .take(26)
      .map((d) => {'name': _str(d['name'], 8), 'total_gb': _num(d['total_gb']), 'free_gb': _num(d['free_gb'])})
      .toList();
  final cores = data['cpu_cores'];
  return {
    'hostname': _str(data['hostname'], 255),
    'os': _str(data['os'], 255),
    'cpu': _str(data['cpu'], 255),
    'cpu_cores': cores is num ? cores.toInt() : null,
    'ram_total_gb': _num(data['ram_total_gb']),
    'ram_used_gb': _num(data['ram_used_gb']),
    'disks': disks,
    'ip': _str(data['ip'], 64),
    if (data['last_boot'] != null) 'last_boot': _str(data['last_boot'], 40),
  };
}

class SysInfo {
  final String computerName;
  final String os;
  final String cpu;
  final String ram; // "8.0 ГБ из 16.0 ГБ"
  final String ip;
  final String disk; // "82 ГБ из 256 ГБ (32% свободно)"
  final double diskFreePercent; // 0.0–1.0
  final String lastBoot;
  final String peerId;
  final List<HealthItem> health;
  SysInfo({
    required this.computerName, required this.os, required this.cpu,
    required this.ram, required this.ip, required this.disk,
    required this.diskFreePercent, required this.lastBoot,
    required this.peerId, required this.health,
  });
}

enum HealthSeverity { ok, info, warn, err }

class HealthItem {
  final HealthSeverity severity;
  final String title;
  final String? subtitle;
  HealthItem({required this.severity, required this.title, this.subtitle});
}

class SysinfoCollector {
  /// Structured snapshot sent to the bridge; null when PowerShell is unavailable.
  Future<Map<String, dynamic>?> collectReport() async {
    try {
      final result = await Process.run(
        'powershell', ['-NoProfile', '-NonInteractive', '-Command', _reportScript],
        stdoutEncoding: utf8,
      );
      return parseSysinfoReport(result.stdout.toString().trim());
    } catch (_) {
      return null;
    }
  }

  Future<SysInfo> collect(String peerId) async {
    final results = await Future.wait([
      _ps('(Get-WmiObject Win32_ComputerSystem).Name'),
      _ps('[System.Environment]::OSVersion.VersionString'),
      _ps('(Get-WmiObject Win32_Processor).Name'),
      _ps('\$os=Get-WmiObject Win32_OperatingSystem; "{0:N1} ГБ из {1:N1} ГБ" -f ((\$os.TotalVisibleMemorySize - \$os.FreePhysicalMemory)/1MB), (\$os.TotalVisibleMemorySize/1MB)'),
      _ps('(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {\$_.InterfaceAlias -notlike "*Loopback*"} | Select-Object -First 1).IPAddress'),
      _ps('\$d=Get-PSDrive C; \$free=\$d.Free; \$total=\$d.Free+\$d.Used; \$pct=[math]::Round(\$free/\$total*100); "{0:N0} ГБ из {1:N0} ГБ (\$pct% свободно)" -f (\$free/1GB), (\$total/1GB)'),
      _ps('((Get-PSDrive C).Free/((Get-PSDrive C).Free+(Get-PSDrive C).Used))'),
      _ps('[System.Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)'),
    ]);

    final freePercent = double.tryParse(results[6].trim()) ?? 0.5;
    final health = _computeHealth(freePercent, results[7]);

    return SysInfo(
      computerName: results[0].trim(),
      os: results[1].trim(),
      cpu: results[2].trim(),
      ram: results[3].trim(),
      ip: results[4].trim(),
      disk: results[5].trim(),
      diskFreePercent: freePercent,
      lastBoot: results[7].trim(),
      peerId: peerId,
      health: health,
    );
  }

  Future<String> _ps(String command) async {
    try {
      final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);
      return result.stdout.toString().trim();
    } catch (_) {
      return '—';
    }
  }

  List<HealthItem> _computeHealth(double diskFreePercent, String lastBootStr) {
    final items = <HealthItem>[];

    // Disk check
    if (diskFreePercent < 0.15) {
      items.add(HealthItem(severity: HealthSeverity.err, title: 'Диск C: почти заполнен', subtitle: 'Свободно менее 15%'));
    } else if (diskFreePercent < 0.25) {
      items.add(HealthItem(severity: HealthSeverity.warn, title: 'Диск C: заканчивается место', subtitle: 'Свободно менее 25%'));
    } else {
      items.add(HealthItem(severity: HealthSeverity.ok, title: 'Место на диске в норме'));
    }

    // Uptime check
    final boot = DateTime.tryParse(lastBootStr);
    if (boot != null) {
      final days = DateTime.now().difference(boot).inDays;
      if (days > 7) {
        items.add(HealthItem(severity: HealthSeverity.warn, title: 'Давно не перезагружался', subtitle: 'Последняя перезагрузка $days дней назад'));
      } else {
        items.add(HealthItem(severity: HealthSeverity.ok, title: 'Компьютер перезагружался недавно'));
      }
    }

    return items;
  }
}
