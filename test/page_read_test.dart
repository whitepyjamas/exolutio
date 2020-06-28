import 'dart:async';
import 'dart:io';

import 'package:exolutio/src/loader.dart';
import 'package:exolutio/src/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLoader extends Mock implements Loader {}

class MockPreferences extends Mock implements SharedPreferences {}

void main() {
  Model model;
  var updated;

  setUp(() {
    final loader = MockLoader();

    when(loader.page(any)).thenAnswer((_) => File(
          'test/evo-lutio.livejournal.com.html',
        ).readAsString());

    when(loader.body(any)).thenAnswer((_) => File(
          'test/evo-lutio.livejournal.com__1180335.html',
        ).readAsString());

    updated = StreamController();
    model = Model(loader, MockPreferences());
    model.addListener(() => updated.add(null));
  });
  tearDown(() {
    updated.close();
    model.dispose();
  });

  test('comment inside article', () async {
    model.loadMore();
    await updated.stream.first;
    final link = model[Tag.letters].first;
    final article = await model.article(link);

    expect(article.text.contains('<span class="quote">'), isTrue);
  });
}