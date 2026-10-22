import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'access_policy.dart';

// [agent] The native half of AccessSync: writes a plan into RustDesk's own settings.
// Kept apart so the sync logic can be unit-tested without the native bridge.
Future<void> applyAccessPlan(AccessPlan plan) async {
  await bind.mainSetPermanentPasswordWithResult(password: plan.permanentPassword ?? '');
  await bind.mainSetOption(key: kOptionVerificationMethod, value: plan.verificationMethod);
  await bind.mainSetOption(key: kOptionApproveMode, value: plan.approveMode);
}
