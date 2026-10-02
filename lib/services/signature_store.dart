import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class SignatureStroke {
  final List<Offset> points;
  int colorValue;
  double width;

  SignatureStroke({
    required this.points,
    required this.colorValue,
    required this.width,
  });

  SignatureStroke copy() => SignatureStroke(
        points: List<Offset>.of(points),
        colorValue: colorValue,
        width: width,
      );
}

class SignatureStore {
  static const _hasSignatureKey = 'esign_doc_pro_has_signature';
  static const _signatureStrokesKey = 'esign_doc_pro_signature_strokes';

  Future<bool> hasSavedSignature() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_hasSignatureKey) ?? false;
  }

  Future<void> saveSignature(List<SignatureStroke> strokes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hasSignatureKey, true);
    final encoded = strokes
        .map((stroke) => {
              'color': stroke.colorValue,
              'width': stroke.width,
              'points': stroke.points
                  .map((point) => {'x': point.dx, 'y': point.dy})
                  .toList(),
            })
        .toList();
    await preferences.setString(_signatureStrokesKey, jsonEncode(encoded));
  }

  Future<List<SignatureStroke>> loadSignature() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_signatureStrokesKey);
    if (raw == null || raw.isEmpty) return <SignatureStroke>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (decoded.isNotEmpty && decoded.first is List<dynamic>) {
        return decoded.map((rawStroke) {
          final points = (rawStroke as List<dynamic>).map((point) {
            final values = point as Map<String, dynamic>;
            return Offset(
              (values['x'] as num).toDouble(),
              (values['y'] as num).toDouble(),
            );
          }).toList();
          return SignatureStroke(
              points: points, colorValue: 0xFF173B4B, width: 3);
        }).toList();
      }
      return decoded.map((rawStroke) {
        final stroke = rawStroke as Map<String, dynamic>;
        final points = (stroke['points'] as List<dynamic>).map((point) {
          final values = point as Map<String, dynamic>;
          return Offset(
            (values['x'] as num).toDouble(),
            (values['y'] as num).toDouble(),
          );
        }).toList();
        return SignatureStroke(
          points: points,
          colorValue: (stroke['color'] as num?)?.toInt() ?? 0xFF173B4B,
          width: (stroke['width'] as num?)?.toDouble() ?? 3,
        );
      }).toList();
    } on FormatException {
      return <SignatureStroke>[];
    } on TypeError {
      return <SignatureStroke>[];
    }
  }

  Future<void> deleteSignature() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_hasSignatureKey);
    await preferences.remove(_signatureStrokesKey);
  }
}
