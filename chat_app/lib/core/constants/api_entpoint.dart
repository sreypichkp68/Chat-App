class ApiEntpoint {
  // Railway deployment
  static const String host = 'chat-app-production-65e9.up.railway.app';
  static String get url => 'https://$host/api';

  // Reverb
  static const reverbKey = '5khygsotvewpdgtiglgj';
  static String get reverbHost => host;
  static const int reverbPort = 443; // see note below
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
  static String get broadcastingAuth => 'https://$host/broadcasting/auth';
}
