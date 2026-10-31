import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';

final myShareProvider = FutureProvider.autoDispose<MyShare?>((ref) async {
  return ref.watch(sharingRepositoryProvider).myShare();
});

final aboutMeProvider = FutureProvider.autoDispose<AboutMe>((ref) async {
  return ref.watch(sharingRepositoryProvider).aboutMe();
});
