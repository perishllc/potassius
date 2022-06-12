import 'package:event_taxi/event_taxi.dart';
import 'package:nautilus_wallet_flutter/model/db/user.dart';

class BlockedAddedEvent implements Event {
  final User? user;

  BlockedAddedEvent({this.user});
}
