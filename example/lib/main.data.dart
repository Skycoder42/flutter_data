// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: directives_ordering, top_level_function_literal_block

import 'package:flutter_data/flutter_data.dart';

import 'package:get_it/get_it.dart';

import 'package:jsonplaceholder_example/models/comment.dart';
import 'package:jsonplaceholder_example/models/post.dart';
import 'package:jsonplaceholder_example/models/user.dart';

// ignore: prefer_function_declarations_over_variables
ConfigureRepositoryLocalStorage configureRepositoryLocalStorage =
    ({FutureFn<String> baseDirFn, List<int> encryptionKey, bool clear}) {
  // ignore: unnecessary_statements
  baseDirFn;
  return hiveLocalStorageProvider.overrideWithProvider(Provider((_) =>
      HiveLocalStorage(
          baseDirFn: baseDirFn, encryptionKey: encryptionKey, clear: clear)));
};

// ignore: prefer_function_declarations_over_variables
RepositoryInitializerProvider repositoryInitializerProvider =
    ({bool remote, bool verbose}) {
  return _repositoryInitializerProviderFamily(
      RepositoryInitializerArgs(remote, verbose));
};

final _repositoryInitializerProviderFamily =
    FutureProvider.family<RepositoryInitializer, RepositoryInitializerArgs>(
        (ref, args) async {
  final adapters = <String, RemoteAdapter>{
    'comments': ref.read(commentRemoteAdapterProvider),
    'posts': ref.read(postRemoteAdapterProvider),
    'users': ref.read(userRemoteAdapterProvider)
  };

  final _commentRepository = ref.read(commentRepositoryProvider);
  _commentRepository.dispose();
  await _commentRepository.initialize(
    remote: args?.remote,
    verbose: args?.verbose,
    adapters: adapters,
  );

  final _postRepository = ref.read(postRepositoryProvider);
  _postRepository.dispose();
  await _postRepository.initialize(
    remote: args?.remote,
    verbose: args?.verbose,
    adapters: adapters,
  );

  final _userRepository = ref.read(userRepositoryProvider);
  _userRepository.dispose();
  await _userRepository.initialize(
    remote: args?.remote,
    verbose: args?.verbose,
    adapters: adapters,
  );

  ref.onDispose(() {
    if (ref.mounted) {
      ref.read(commentRepositoryProvider).dispose();
      ref.read(postRepositoryProvider).dispose();
      ref.read(userRepositoryProvider).dispose();
    }
  });

  return RepositoryInitializer();
});

extension GetItFlutterDataX on GetIt {
  void registerRepositories(
      {FutureFn<String> baseDirFn,
      List<int> encryptionKey,
      bool clear,
      bool remote,
      bool verbose}) {
    final i = GetIt.instance;

    final _container = ProviderContainer(
      overrides: [
        configureRepositoryLocalStorage(
            baseDirFn: baseDirFn, encryptionKey: encryptionKey, clear: clear),
      ],
    );

    if (i.isRegistered<RepositoryInitializer>()) {
      return;
    }

    i.registerSingletonAsync<RepositoryInitializer>(() async {
      return _container.read(
          repositoryInitializerProvider(remote: remote, verbose: verbose)
              .future);
    });
    i.registerSingletonWithDependencies<Repository<Comment>>(
        () => _container.read(commentRepositoryProvider),
        dependsOn: [RepositoryInitializer]);

    i.registerSingletonWithDependencies<Repository<Post>>(
        () => _container.read(postRepositoryProvider),
        dependsOn: [RepositoryInitializer]);

    i.registerSingletonWithDependencies<Repository<User>>(
        () => _container.read(userRepositoryProvider),
        dependsOn: [RepositoryInitializer]);
  }
}
