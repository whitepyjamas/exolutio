import 'package:exolutio/src/model.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'home/screen.dart';
import 'read/screen.dart';

class Exolutio extends StatelessWidget {
  final _model = locator<Model>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exolutio',
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
      routes: {
        '/': (context) => HomeScreen(),
        '/read': (context) => FutureBuilder(
              future: _model.article(ModalRoute.of(context).settings.arguments),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ArticleScreen(snapshot.data);
                } else if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error));
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
      },
      // https://github.com/Sub6Resources/flutter_html/issues/294#issuecomment-637318948
      builder: (BuildContext context, Widget child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
        child: child,
      ),
    );
  }
}
