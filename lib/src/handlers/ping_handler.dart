import 'package:logging/logging.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';

class PingHandler extends Handler {
  PingHandler() : super(Logger('PingHandler'));

  @override
  Buffer createRequest() {
    log.finest('Creating buffer for PingHandler');
    final buffer = Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
}
