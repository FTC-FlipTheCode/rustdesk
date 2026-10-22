// [agent] What to configure in RustDesk for the unattended-access state the bridge reports.
// Pure, so it is unit-tested without the native bridge.

class AccessPlan {
  /// The permanent password to set, or null to clear it.
  final String? permanentPassword;

  /// RustDesk `approve-mode`: 'password' = no click needed, '' = RustDesk default (click or password).
  final String approveMode;

  /// RustDesk `verification-method`: 'use-permanent-password' or '' (temporary or permanent).
  final String verificationMethod;

  const AccessPlan({this.permanentPassword, required this.approveMode, required this.verificationMethod});

  @override
  bool operator ==(Object other) =>
      other is AccessPlan &&
      other.permanentPassword == permanentPassword &&
      other.approveMode == approveMode &&
      other.verificationMethod == verificationMethod;

  @override
  int get hashCode => Object.hash(permanentPassword, approveMode, verificationMethod);
}

/// Switched on and a password delivered: technicians connect with it and the client is not asked.
/// Anything else: back to the stock behaviour, where the client sees the request and presses «Принять».
AccessPlan planFor({required bool unattended, String? password}) {
  if (unattended && password != null && password.isNotEmpty) {
    return AccessPlan(
        permanentPassword: password, approveMode: 'password', verificationMethod: 'use-permanent-password');
  }
  return const AccessPlan(approveMode: '', verificationMethod: '');
}
