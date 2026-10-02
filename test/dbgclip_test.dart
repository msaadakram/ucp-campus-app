import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
  testWidgets('clipboard behavior', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    try {
      await Clipboard.setData(const ClipboardData(text: 'hi'));
      debugPrint('CLIPBOARD_OK');
    } catch (e) {
      debugPrint('CLIPBOARD_THROW: ${e.runtimeType}');
    }
  });
}
