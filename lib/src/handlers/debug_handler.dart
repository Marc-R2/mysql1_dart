import 'package:logging/logging.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';

class DebugHandler extends Handler {
  DebugHandler() : super(Logger('DebugHandler'));

  @override
  Buffer createRequest() {
    final buffer = Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
}
