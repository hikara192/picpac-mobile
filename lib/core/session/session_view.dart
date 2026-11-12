import 'package:api_contract/api_contract.dart';

final class SessionView {
  const SessionView({this.session, this.customer, this.expiryCount = 0});

  final AuthSession? session;

  final Customer? customer;

  final int expiryCount;

  bool get hasSession => session != null;

  UserRole get role => session?.role ?? UserRole.guest;

  bool get isAccount =>
      role == UserRole.customer || role == UserRole.supportAgent;

  bool get isCustomer => role == UserRole.customer;

  bool get isSupportAgent => role == UserRole.supportAgent;

  SessionView withCustomer(Customer profile) => SessionView(
    session: session,
    customer: profile,
    expiryCount: expiryCount,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionView &&
      other.session?.token == session?.token &&
      other.session?.role == session?.role &&
      other.customer?.id == customer?.id &&
      other.expiryCount == expiryCount;

  @override
  int get hashCode =>
      Object.hash(session?.token, session?.role, customer?.id, expiryCount);
}
