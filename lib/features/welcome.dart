import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/controller.dart';
import '../domain/models.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, hidden = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(schoolProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth > 760;
                  final intro = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Brand(),
                      const SizedBox(height: 40),
                      const Pill('A BETTER SCHOOL DAY'),
                      const SizedBox(height: 22),
                      Text(
                        'Small moments.\nBrighter futures.',
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: wide ? 57 : 42,
                          height: 1.1,
                          letterSpacing: -1.8,
                          color: isDark(context) ? mint : ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Learning, people, and possibilities.\nOne thoughtful place to bring your school together.',
                        style: TextStyle(fontSize: 15, height: 1.8),
                      ),
                      const SizedBox(height: 28),
                      const Center(child: CampusArt(height: 220)),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            size: 17,
                            color: teal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              school.live
                                  ? 'Your school. Your secure workspace.'
                                  : 'Portfolio demo · Fictional school data',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crafted by InGrowwth Innovations',
                        style: TextStyle(fontSize: 11, color: teal),
                      ),
                    ],
                  );
                  final login = Surface(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          school.live
                              ? 'Welcome back.'
                              : 'Step into your school.',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          school.live
                              ? 'Sign in with your school account.'
                              : 'Choose a role to explore a connected school day.\nChanges are saved on this device.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (school.live)
                          Form(
                            key: form,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'School email',
                                  ),
                                  validator: (v) => v != null && v.contains('@')
                                      ? null
                                      : 'Enter your email',
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: password,
                                  obscureText: hidden,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => hidden = !hidden),
                                      icon: Icon(
                                        hidden
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => v?.isNotEmpty == true
                                      ? null
                                      : 'Enter your password',
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (!form.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            setState(() => busy = true);
                                            await runAction(
                                              context,
                                              () => school.signIn(
                                                email.text,
                                                password.text,
                                              ),
                                            );
                                            if (mounted) {
                                              setState(() => busy = false);
                                            }
                                          },
                                    child: Text(
                                      busy ? 'Signing in…' : 'Sign in',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          if (!email.text.contains('@')) {
                                            await runAction(
                                              context,
                                              () async => throw StateError(
                                                'Enter your school email first.',
                                              ),
                                            );
                                            return;
                                          }
                                          await runAction(
                                            context,
                                            () => school.backend!.client.auth
                                                .resetPasswordForEmail(
                                                  email.text.trim(),
                                                ),
                                            'Password reset email requested.',
                                          );
                                        },
                                  child: const Text('Forgot password?'),
                                ),
                              ],
                            ),
                          )
                        else
                          ...demoUsers.map(
                            (user) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Surface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                color: isDark(context)
                                    ? null
                                    : const Color(0xFFF8FAF4),
                                onTap: () => school.enterDemo(user),
                                child: Row(
                                  children: [
                                    PersonAvatar(
                                      user.name,
                                      color: user.role == SchoolRole.student
                                          ? clay
                                          : teal,
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.role.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                      color: teal,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: intro),
                            const SizedBox(width: 64),
                            Expanded(child: login),
                          ],
                        )
                      : Column(
                          children: [intro, const SizedBox(height: 32), login],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
