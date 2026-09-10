class ApiEntpoint {
  //Real Device
  static const String host = '192.168.100.218';
  static String get url => 'http://$host:8000/api';

  // Reverb
  static const reverbKey = '5khygsotvewpdgtiglgj';
  static String get reverbHost => host;
  static const int reverbPort = 8080;

  static String get callInvite => '$url/calls/invite';
  static String get callAccept => '$url/calls/accept';
  static String get callDecline => '$url/calls/decline';
  static String get callEnd => '$url/calls/end';
  static String get callToken => '$url/calls/token';

  static String get register => '$url/register';
  static String get login => '$url/login';
  static String get currentUser => '$url/user';
  static String get conversations => '$url/conversations';
  static String get searchUsers => '$url/users/search';
  static String get friendRequests => '$url/friend-requests';
  static String get friends => '$url/friends';
  static String get uploadMessageImage => '$url/messages/upload';
  static String get broadcastingAuth => 'http://$host:8000/broadcasting/auth';

}
