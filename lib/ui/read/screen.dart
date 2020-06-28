import 'dart:async';

import 'package:exolutio/src/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../common.dart';

const _fontSize = 17.0;
const _jumpDuration = Duration(milliseconds: 300);

class ArticleScreen extends StatefulWidget {
  ArticleScreen(this.context);

  final context;

  @override
  _ArticleScreenState createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final _model = locator<Model>();
  final _scroll = AutoScrollController();
  _Jumper _jumper;

  Article _data;
  String _title;

  @override
  void initState() {
    var arguments = _getScreenArguments(widget.context);
    _articleAsFuture(arguments[1]).then(_initStateWithData);
    _title = arguments[0];
    _jumper = _Jumper(this);
    _jumper.mode.listen((value) => setState(() {}));
    _jumper.position.listen(_animateTo);

    _scroll.addListener(() {
      if (!_jumper.jumped || _jumper.returned) {
        _jumper.clear();
        _model.savePosition(
          _data,
          _scroll.offset,
        );
      }
    });

    super.initState();
  }

  void _initStateWithData(Article value) {
    _data = value;
    _animateTo(_model.getPosition(_data));
    setState(() {});
  }

  @override
  void dispose() {
    _jumper.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _jumper.jumped ? _jumper.setBacked : _jumper.setJumpedStart,
        child: Icon(_floatingIcon),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              controller: _scroll,
              slivers: [
                _buildAppBar(),
                if (_data != null) _buildHtml(),
                if (_data != null) _buildComments(),
                if (_data != null) _buildFloatingMargin(),
                if (_data == null) SliverProgressIndicator(),
              ],
            ),
            Column(
              children: <Widget>[
                Spacer(),
                _Progress(this),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData get _floatingIcon {
    switch (_jumper.mode.value) {
      case JumpMode.start:
        return Icons.arrow_downward;
      default:
        return Icons.arrow_upward;
    }
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: AppBarHeight,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_title),
      ),
      centerTitle: true,
    );
  }

  Widget _buildComments() {
    return SliverList(
      delegate: SliverChildListDelegate(
        _data.comments
            .map(
              (e) => AutoScrollTag(
                index: _data.comments.indexOf(e),
                controller: _scroll,
                key: ValueKey(_data.comments.indexOf(e)),
                child: Card(
                  elevation: 3,
                  color: e.dname == e.poster ? _authorColor : null,
                  child: Column(
                    children: <Widget>[
                      Text(
                        e.dname,
                        style: TextStyle(
                          color: e.dname == e.poster
                              ? Colors.white
                              : Theme.of(context).disabledColor,
                          shadows: <Shadow>[
                            Shadow(
                              offset: Offset(0.0, 1.0),
                              blurRadius: 2.0,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ],
                        ),
                      ),
                      Html(
                        data: '<article>${e.article}</article>',
                        style: e.dname == e.poster ? _authorStyle : _htmlStyle,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHtml() {
    return SliverToBoxAdapter(
      child: Html(
        onLinkTap: _onLinkTap,
        data: _data.text,
        style: _htmlStyle,
      ),
    );
  }

  Map<String, Style> get _htmlStyle => {
        'article': Style(fontSize: FontSize(_fontSize)),
        '.quote': Style(fontSize: FontSize(_fontSize), color: _accentColor),
      };

  Map<String, Style> get _authorStyle => {
        'article': Style(fontSize: FontSize(_fontSize), color: Colors.white),
        '.quote': Style(fontSize: FontSize(_fontSize), color: _accentColor),
      };

  Color get _authorColor => Theme.of(context).brightness == Brightness.dark
      ? _accentColor.withAlpha(100)
      : _accentColor;

  Color get _accentColor => Theme.of(context).accentColor;

  void _onLinkTap(String url) {
    if (url.startsWith(CommentLink)) {
      final index = url.substring(CommentLink.length);
      _jumper.setJumpedComment(int.parse(index));
    } else {
      launch(url);
    }
  }

  Widget _buildFloatingMargin() {
    return SliverToBoxAdapter(child: Container(height: 80));
  }

  void _animateTo(double position) {
    if (position != null) {
      _scroll.animateTo(
        position,
        duration: _jumpDuration,
        curve: Curves.easeOutExpo,
      );
    }
  }

  List _getScreenArguments(BuildContext context) {
    return ModalRoute.of(context).settings.arguments as List;
  }

  Future<Article> _articleAsFuture(Link argument) {
    var futureOr = _model.article(argument);
    if (futureOr is Article) {
      return Future.value(futureOr);
    } else {
      return futureOr;
    }
  }
}

class _Progress extends StatefulWidget {
  final _ArticleScreenState reading;

  _Progress(this.reading);

  @override
  _ProgressState createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  @override
  void initState() {
    widget.reading._scroll.addListener(() => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reading._data == null) {
      return LinearProgressIndicator();
    }

    var position = widget.reading._scroll.position;
    var value = position.pixels / position.maxScrollExtent;
    if (value.isInfinite || value.isNaN) {
      return LinearProgressIndicator(value: 0.0);
    } else {
      return LinearProgressIndicator(value: value);
    }
  }
}

enum JumpMode {
  none,
  start,
  comment,
  back,
}

class _Jumper {
  bool _jumpedUp;
  double _jumpedFrom;
  final _ArticleScreenState reading;
  final mode = BehaviorSubject<JumpMode>()..add(JumpMode.none);
  final position = PublishSubject<double>();

  _Jumper(this.reading);

  void dispose() {
    mode.close();
    position.close();
  }

  bool get jumped => mode.value != JumpMode.none;

  bool get returned {
    return _jumpedUp
        ? reading._scroll.offset >= _jumpedFrom
        : reading._scroll.offset <= _jumpedFrom;
  }

  set _modeSetter(JumpMode event) {
    mode.add(event);
    switch (event) {
      case JumpMode.none:
        position.add(null);
        break;
      case JumpMode.start:
        position.add(0);
        break;
      case JumpMode.comment:
        // controlled by plugin
        break;
      case JumpMode.back:
        position.add(_jumpedFrom);
        break;
      default:
        throw UnsupportedError(event.toString());
    }
  }

  void setJumpedStart() {
    _jumpedUp = true;
    _jumpedFrom = reading._scroll.offset;
    _modeSetter = JumpMode.start;
  }

  void setJumpedComment(int index) {
    _jumpedUp = false;
    _jumpedFrom = reading._scroll.offset;
    _modeSetter = JumpMode.comment;
    reading._scroll.scrollToIndex(
      index,
      duration: _jumpDuration,
      preferPosition: AutoScrollPosition.begin,
    );
    // ignore: invalid_use_of_protected_member
    reading.setState(() {}); // TODO
  }

  void setBacked() {
    if (jumped) {
      _modeSetter = JumpMode.back;
      clear();
    }
  }

  void clear() {
    if (jumped) {
      _jumpedUp = null;
      _jumpedFrom = null;
      _modeSetter = JumpMode.none;
    }
  }
}
