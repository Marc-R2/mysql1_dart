import 'package:logging/logging.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';
import 'package:mysql1/src/mysql_protocol_error.dart';

class QuitHandler extends Handler {
  QuitHandler() : super(Logger('QuitHandler'));

  @override
  Buffer createRequest() {
    final buffer = Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    throw createMySqlProtocolError(
      "Shouldn't have received a response after sending a QUIT message",
    );
  }
}
