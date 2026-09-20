abstract class Failures {
  final String message;
  const Failures(this.message);
}

class SeverFail extends Failures {
  SeverFail([super.message = 'Server Failure']);
}

class CacheFail extends Failures {
  CacheFail([super.message = 'CacheFail']);
}
