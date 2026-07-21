import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final text = File(args[0]).readAsStringSync();
  final wptPattern = RegExp(r'<wpt lat="([^"]+)" lon="([^"]+)">\s*<name>([^<]*)</name>');
  final trkptPattern = RegExp(r'<trkpt lat="([^"]+)" lon="([^"]+)">');

  final wpts = wptPattern.allMatches(text).map((m) => {
        'lat': double.parse(m.group(1)!),
        'lng': double.parse(m.group(2)!),
        'name': m.group(3)!,
      }).toList();

  final trkpts = trkptPattern.allMatches(text).map((m) => {
        'lat': double.parse(m.group(1)!),
        'lng': double.parse(m.group(2)!),
      }).toList();

  final nameMatch = RegExp(r'<metadata><name>([^<]*)</name>').firstMatch(text);

  print(jsonEncode({
    'name': nameMatch?.group(1) ?? '',
    'wpts': wpts,
    'trkpts': trkpts,
  }));
}
