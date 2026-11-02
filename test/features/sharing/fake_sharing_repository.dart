import 'dart:async';

import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';

class FakeSharingRepository implements SharingRepository {
  Invite? openInviteValue;
  Invite? createInviteValue;
  String previewInviteValue = '';
  MyShare? myShareValue;
  SharedGoals? sharedGoalsValue;
  AboutMe aboutMeValue = const AboutMe();

  final List<String> calls = [];
  Object? failWith;
  Completer<void>? gate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<Invite?> openInvite(String personId) async {
    await _record('openInvite($personId)');
    return openInviteValue;
  }

  @override
  Future<Invite> createInvite(String personId) async {
    await _record('createInvite($personId)');
    return createInviteValue!;
  }

  @override
  Future<void> cancelInvite(String personId) async {
    await _record('cancelInvite($personId)');
  }

  @override
  Future<String> previewInvite(String code) async {
    await _record('previewInvite($code)');
    return previewInviteValue;
  }

  @override
  Future<void> acceptInvite(String code, Set<ShareItem> items) async {
    await _record('acceptInvite($code, ${items.length} items)');
  }

  @override
  Future<MyShare?> myShare() async {
    await _record('myShare()');
    return myShareValue;
  }

  @override
  Future<void> setItems(Set<ShareItem> items) async {
    await _record('setItems(${items.length} items)');
  }

  @override
  Future<void> stopSharing() async {
    await _record('stopSharing()');
  }

  @override
  Future<SharedGoals?> sharedGoals(String personId, DateTime month) async {
    await _record('sharedGoals($personId, ${month.year}-${month.month})');
    return sharedGoalsValue;
  }

  @override
  Future<void> stopSharingWith(String personId) async {
    await _record('stopSharingWith($personId)');
  }

  @override
  Future<AboutMe> aboutMe() async {
    await _record('aboutMe()');
    return aboutMeValue;
  }

  @override
  Future<void> saveAboutMe(AboutMe aboutMe) async {
    await _record('saveAboutMe()');
    aboutMeValue = aboutMe;
  }
}
