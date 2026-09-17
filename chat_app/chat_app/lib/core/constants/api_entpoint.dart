
class ApiEntpoint {
  // Laravel API
  static const String host = 'chat-app-production-65e9.up.railway.app';

  static String get url => 'https://$host/api';

  // Railway Reverb
  static const String reverbHost =
      'proactive-manifestation-production-f5c8.up.railway.app';

  static const int reverbPort = 443;

  // Must match Railway REVERB_APP_KEY
  static const String reverbKey = 'c7f2344f4ad21db636feca3ad31a84bc';

  // Laravel handles private-channel authentication
  static String get broadcastingAuth => 'https://$host/api/broadcasting/auth';

  static String get callInvite => '$url/calls/invite';
  static String get callAccept => '$url/calls/accept';
  static String get callDecline => '$url/calls/decline';
  static String callEnd(String callId) => '$url/calls/$callId/end';
  static String get callToken => '$url/calls/token';

  static String get register => '$url/register';
  static String get login => '$url/login';
  static String get currentUser => '$url/user/profile';

  static String get conversations => '$url/conversations';
  static String get searchUsers => '$url/users/search';
  static String get friendRequests => '$url/friend-requests';
  static String get friends => '$url/friends';

  static String get uploadMessageImage => '$url/messages/upload';
}
