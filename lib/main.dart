import 'dart:async';
import 'dart:convert';

import 'package:comiko/app_state.dart';
import 'package:comiko/pages/about_us_page.dart';
import 'package:comiko/pages/artists_page.dart';
import 'package:comiko/pages/liked_events_page.dart';
import 'package:comiko/pages/upcoming_events_page.dart';
import 'package:comiko_backend/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:redux/redux.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final GoogleSignIn _googleSignIn = new GoogleSignIn();

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  static final Store<AppState> store = new Store(
    combineReducers([reducer as Reducer]),
    initialState: new AppState.initial(),
  );

  @override
  Widget build(BuildContext context) {
    return new StoreProvider(
      store: store,
      child: new MaterialApp(
        title: 'Comiko',
        theme: new ThemeData.dark(),
        home: new MyHomePage(title: 'Flutter Demo Home Page', store: store),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Store<AppState> store;
  final String title;

  MyHomePage({
    Key key,
    this.title,
    @required this.store,
  })
      : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState(store: store);
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final Store<AppState> store;

  int _currentIndex = 0;
  List<NavigationIconView> _navigationViews;
  bool _showDrawerContents = true;

  AnimationController _controller;
  Animation<double> _drawerContentsOpacity;
  Animation<Offset> _drawerDetailsPosition;

  _MyHomePageState({
    @required this.store,
  });

  Future<Null> initServices() async {
    String eventString = await rootBundle.loadString('lib/data/events.json');
    List<Map<String, dynamic>> eventJson = JSON.decode(eventString);
    JsonEventService service = ServiceProvider.get(EventService);
    service.init(eventJson);
    store.dispatch(new FetchEventsAction());
  }

  Future<FirebaseUser> _signInWithGoogle() async {
    var googleUser = _googleSignIn.currentUser;
    if (googleUser == null) googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) {
      googleUser = await _googleSignIn.signIn();
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final FirebaseUser user = await _auth.signInWithGoogle(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    assert(user.email != null);
    assert(user.displayName != null);
    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);

    final FirebaseUser currentUser = await _auth.currentUser();
    assert(user.uid == currentUser.uid);

    return currentUser;
  }

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _drawerContentsOpacity = new CurvedAnimation(
      parent: new ReverseAnimation(_controller),
      curve: Curves.fastOutSlowIn,
    );
    _drawerDetailsPosition = new Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    )
        .animate(
      new CurvedAnimation(
        parent: _controller,
        curve: Curves.fastOutSlowIn,
      ),
    );

    initServices();
    _navigationViews = <NavigationIconView>[
      new NavigationIconView(
        icon: const Icon(Icons.event_available),
        body: new UpcomingEventsPage(store: store),
        title: const Text('À venir'),
        color: new Color.fromARGB(0xFF, 0xF4, 0x43, 0x36),
        vsync: this,
      ),
      new NavigationIconView(
        icon: const Icon(Icons.favorite),
        body: new LikedEventsPage(store: store),
        title: const Text('Favoris'),
        color: new Color.fromARGB(0xFF, 0x00, 0xBC, 0xD4),
        vsync: this,
      ),
      new NavigationIconView(
        icon: const Icon(Icons.mic),
        body: new ArtistsPage(),
        title: const Text('Artistes'),
        color: new Color.fromARGB(0xFF, 0x75, 0x75, 0x75),
        vsync: this,
      ),
      new NavigationIconView(
        icon: new Icon(Icons.insert_emoticon),
        body: new AboutUsPage(),
        title: const Text('Comiko'),
        color: new Color.fromARGB(0xFF, 0xD3, 0x2F, 0x2F),
        vsync: this,
      ),
    ];

    for (NavigationIconView view in _navigationViews) {
      view.controller.addListener(_rebuild);
    }

    _navigationViews[_currentIndex].controller.value = 1.0;
  }

  @override
  void dispose() {
    for (NavigationIconView view in _navigationViews) {
      view.controller.dispose();
    }

    super.dispose();
  }

  void _rebuild() {
    setState(() {
      // Rebuild in order to animate views.
    });
  }

  Widget _buildTransitionsStack() {
    final List<FadeTransition> transitions = <FadeTransition>[];

    for (NavigationIconView view in _navigationViews) {
      transitions.add(view.transition(context));
    }

    // We want to have the newly animating (fading in) views on top.
    transitions.sort((FadeTransition a, FadeTransition b) {
      final Animation<double> aAnimation = a.listenable;
      final Animation<double> bAnimation = b.listenable;
      final double aValue = aAnimation.value;
      final double bValue = bAnimation.value;
      return aValue.compareTo(bValue);
    });

    return new Stack(children: transitions);
  }

  @override
  Widget build(BuildContext context) {
    final BottomNavigationBar botNavBar = new BottomNavigationBar(
      items: _navigationViews
          .map((NavigationIconView navigationView) => navigationView.item)
          .toList(),
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.shifting,
      onTap: (int index) {
        setState(() {
          _navigationViews[_currentIndex].controller.reverse();
          _currentIndex = index;
          _navigationViews[_currentIndex].controller.forward();
        });
      },
    );

    return new Scaffold(
      drawer: new Drawer(
        child: new ListView(
          children: <Widget>[
            new UserAccountsDrawerHeader(
              accountName: new Text(_googleSignIn.currentUser != null
                  ? _googleSignIn.currentUser.displayName
                  : "Not logged in"),
              accountEmail: new Text(_googleSignIn.currentUser != null
                  ? _googleSignIn.currentUser.email
                  : ""),
              currentAccountPicture: _googleSignIn.currentUser != null
                  ? new CircleAvatar(
                      backgroundImage:
                          new NetworkImage(_googleSignIn.currentUser.photoUrl),
                    )
                  : null,
              onDetailsPressed: () {
                _showDrawerContents = !_showDrawerContents;
                if (_showDrawerContents)
                  _controller.reverse();
                else
                  _controller.forward();
              },
            ),
            new ClipRect(
              child: new Stack(
                children: <Widget>[
                  // The initial contents of the drawer.
                  new FadeTransition(
                    opacity: _drawerContentsOpacity,
                    child: new Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        new ListTile(
                          leading: new CircleAvatar(child: new Text("E")),
                          title: new Text('Example item'),
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  // The drawer's "details" view.
                  new SlideTransition(
                    position: _drawerDetailsPosition,
                    child: new FadeTransition(
                      opacity: new ReverseAnimation(_drawerContentsOpacity),
                      child: new Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _googleSignIn.currentUser == null
                              ? new ListTile(
                                  leading: const Icon(Icons.account_box),
                                  title: new Text('Sign in with google'),
                                  onTap: () {
                                    _signInWithGoogle().then((account) {
                                      _rebuild();
                                    });
                                  },
                                )
                              : new ListTile(
                                  leading: const Icon(Icons.exit_to_app),
                                  title: new Text('Log out'),
                                  onTap: () {
                                    _googleSignIn.signOut().then((account) {
                                      _rebuild();
                                    });
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: new Center(child: _buildTransitionsStack()),
      bottomNavigationBar: botNavBar,
    );
  }
}

class NavigationIconView {
  NavigationIconView({
    Widget icon,
    Widget body,
    Widget title,
    Color color,
    TickerProvider vsync,
  })
      : _body = body,
        item = new BottomNavigationBarItem(
          icon: icon,
          title: title,
          backgroundColor: color,
        ),
        controller = new AnimationController(
          duration: kThemeAnimationDuration,
          vsync: vsync,
        ) {
    _animation = new CurvedAnimation(
      parent: controller,
      curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
    );
  }

  final Widget _body;
  final BottomNavigationBarItem item;
  final AnimationController controller;
  CurvedAnimation _animation;

  FadeTransition transition(BuildContext context) {
    return new FadeTransition(
      opacity: _animation,
      child: new SlideTransition(
        position: new Tween<Offset>(
          begin: const Offset(0.0, 0.02),
          end: Offset.zero,
        )
            .animate(_animation),
        child: _body,
      ),
    );
  }
}
