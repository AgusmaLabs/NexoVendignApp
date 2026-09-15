import 'package:flutter/material.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../operator/presentation/operator_bootstrap_page.dart';
import '../application/authentication_state.dart';
import 'login_page.dart';

/// Root gate: login → session → operator bootstrap → shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final auth = deps.authenticationController;
    final operator = deps.operatorBootstrapController;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[auth, operator]),
      builder: (context, _) {
        final authState = auth.state;
        if (authState is Authenticated) {
          return OperatorBootstrapPage(
            controller: operator,
            onSignOut: () {
              operator.clear();
              auth.signOut();
            },
          );
        }
        return LoginPage(controller: auth);
      },
    );
  }
}
