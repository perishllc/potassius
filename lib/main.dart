import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';
import 'package:logger/logger.dart';
import 'package:magic_sdk/magic_sdk.dart';
import 'package:oktoast/oktoast.dart';
import 'package:wallet_flutter/appstate_container.dart';
import 'package:wallet_flutter/firebase_options.dart';
import 'package:wallet_flutter/generated/l10n.dart';
import 'package:wallet_flutter/localize.dart';
import 'package:wallet_flutter/model/available_currency.dart';
import 'package:wallet_flutter/model/available_language.dart';
import 'package:wallet_flutter/model/vault.dart';
import 'package:wallet_flutter/service_locator.dart';
import 'package:wallet_flutter/styles.dart';
import 'package:wallet_flutter/ui/avatar/avatar.dart';
import 'package:wallet_flutter/ui/avatar/avatar_change.dart';
import 'package:wallet_flutter/ui/gift/gift_paper_wallet.dart';
import 'package:wallet_flutter/ui/home_page.dart';
import 'package:wallet_flutter/ui/intro/intro_backup_confirm.dart';
import 'package:wallet_flutter/ui/intro/intro_backup_safety.dart';
import 'package:wallet_flutter/ui/intro/intro_backup_seed.dart';
import 'package:wallet_flutter/ui/intro/intro_import_seed.dart';
import 'package:wallet_flutter/ui/intro/intro_login.dart';
import 'package:wallet_flutter/ui/intro/intro_magic_password.dart';
import 'package:wallet_flutter/ui/intro/intro_new_existing.dart';
import 'package:wallet_flutter/ui/intro/intro_password.dart';
import 'package:wallet_flutter/ui/intro/intro_password_on_launch.dart';
import 'package:wallet_flutter/ui/intro/intro_welcome.dart';
import 'package:wallet_flutter/ui/lock_screen.dart';
import 'package:wallet_flutter/ui/password_lock_screen.dart';
import 'package:wallet_flutter/ui/purchase_nano.dart';
import 'package:wallet_flutter/ui/register/register_nano_to_username.dart';
import 'package:wallet_flutter/ui/register/register_onchain_username.dart';
import 'package:wallet_flutter/ui/scan/before_scan_screen.dart';
import 'package:wallet_flutter/ui/scan/scan_screen.dart';
import 'package:wallet_flutter/ui/swap/swap_xmr_screen.dart';
import 'package:wallet_flutter/ui/util/routes.dart';
import 'package:wallet_flutter/ui/widgets/dialog.dart';
import 'package:wallet_flutter/util/caseconverter.dart';
import 'package:wallet_flutter/util/nanoutil.dart';
import 'package:wallet_flutter/util/sharedprefsutil.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load environment variables:
  await dotenv.load();

  // Setup Service Provide
  setupServiceLocator();
  // Setup logger, only show warning and higher in release mode.
  if (kReleaseMode) {
    Logger.level = Level.warning;
  } else {
    // Logger.level = Level.debug;
    Logger.level = Level.verbose;
  }
  // Setup firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform, name: "wallet_flutter");

  await FirebaseAppCheck.instance.activate(
    webRecaptchaSiteKey: dotenv.env["CAPTCHA_SITE_KEY"],
  );
  FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  if (!kReleaseMode) {
    // we have to stall for whatever reason in debug mode
    // otherwise the app doesn't start properly (black screen)
    await Future<dynamic>.delayed(const Duration(seconds: 3));
  }
  // Run app
  if (kReleaseMode) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  if (kDebugMode) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const StateContainer(child: App()));

  Magic.instance = Magic(dotenv.env["MAGIC_SDK_KEY"]!);
}

class App extends StatefulWidget {
  const App() : super();

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  @override
  void initState() {
    super.initState();
  }

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StateContainer.of(context).curTheme.statusBar!);
    // final ThemeData theme = ThemeData();
    return OKToast(
      textStyle: AppStyles.textStyleSnackbar(context),
      backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: NonTranslatable.appName,
        // theme: ThemeData(
        //   dialogBackgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        //   primaryColor: StateContainer.of(context).curTheme.primary,
        //   accentColor: StateContainer.of(context).curTheme.primary10,
        //   backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        //   fontFamily: "NunitoSans",
        //   brightness: Brightness.dark,
        // ),
        theme: ThemeData(
          // colorSchemeSeed: StateContainer.of(context).curTheme.primary,
          colorScheme: ColorScheme.fromSeed(seedColor: StateContainer.of(context).curTheme.primary ?? Colors.blue).copyWith(
            secondary: StateContainer.of(context).curTheme.primary10,
            brightness: StateContainer.of(context).curTheme.brightness,
            error: StateContainer.of(context).curTheme.error,
            primary: StateContainer.of(context).curTheme.primary,
            background: StateContainer.of(context).curTheme.backgroundDark,
            tertiary: StateContainer.of(context).curTheme.warning,
          ),
          // dialogBackgroundColor: StateContainer.of(context).curTheme.backgroundDarkest,
          // primaryColor: StateContainer.of(context).curTheme.primary,
          // brightness: StateContainer.of(context).curTheme.brightness,
          // textTheme: TextTheme(
          //   bodySmall: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   bodyMedium: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   bodyLarge: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   displaySmall: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   displayMedium: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   displayLarge: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   labelSmall: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   labelMedium: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   labelLarge: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   headlineSmall: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   headlineMedium: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   headlineLarge: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   titleSmall: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   titleMedium: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          //   titleLarge: TextStyle(
          //     color: StateContainer.of(context).curTheme.text,
          //   ),
          // ),
          fontFamily: "NunitoSans",
          useMaterial3: true,
          // colorScheme: ColorScheme.fromSwatch().copyWith(
          //   secondary: StateContainer.of(context).curTheme.primary10,
          //   brightness: StateContainer.of(context).curTheme.brightness,
          //   error: StateContainer.of(context).curTheme.error,
          //   primary: StateContainer.of(context).curTheme.primary,
          //   background: StateContainer.of(context).curTheme.background,
          //   tertiary: StateContainer.of(context).curTheme.warning,
          // ),
          brightness: StateContainer.of(context).curTheme.brightness,
          // scaffoldBackgroundColor: StateContainer.of(context).curTheme.background,
        ),
        localizationsDelegates: [
          ZsDelegate(StateContainer.of(context).curLanguage),
          Z.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],

        locale: StateContainer.of(context).curLanguage.language == AvailableLanguage.DEFAULT
            ? null
            : StateContainer.of(context).curLanguage.getLocale(),
        supportedLocales: Z.delegate.supportedLocales,
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          switch (settings.name) {
            case '/':
              return NoTransitionRoute(
                builder: (_) => Splash(),
                settings: settings,
              );
            case '/home':
              return NoTransitionRoute(
                builder: (_) => Stack(
                  children: [
                    AppHomePage(priceConversion: settings.arguments as PriceConversion?),
                    Magic.instance.relayer,
                  ],
                ),
                settings: settings,
              );
            case '/home_transition':
              return NoPopTransitionRoute(
                builder: (_) => AppHomePage(priceConversion: settings.arguments as PriceConversion?),
                settings: settings,
              );
            case '/intro_welcome':
              return NoTransitionRoute(
                builder: (_) => IntroWelcomePage(),
                settings: settings,
              );
            case '/intro_login':
              return NoTransitionRoute(
                builder: (_) => Stack(
                  children: [
                    IntroLoginPage(),
                    Magic.instance.relayer,
                  ],
                ),
                settings: settings,
              );
            case '/intro_magic_password':
              return MaterialPageRoute(
                builder: (_) => IntroMagicPassword(
                  entryExists: (settings.arguments! as Map<String, dynamic>)["entryExists"] as bool,
                  identifier: (settings.arguments! as Map<String, dynamic>)["issuer"] as String?,
                ),
                settings: settings,
              );
            case '/intro_new_existing':
              return MaterialPageRoute(
                builder: (_) => IntroNewExistingPage(),
                settings: settings,
              );
            case '/intro_password_on_launch':
              return MaterialPageRoute(
                builder: (_) => IntroPasswordOnLaunch(seed: settings.arguments as String?),
                settings: settings,
              );
            case '/intro_password':
              return MaterialPageRoute(
                builder: (_) => IntroPassword(seed: settings.arguments as String?),
                settings: settings,
              );
            case '/intro_backup':
              return MaterialPageRoute(
                builder: (_) => IntroBackupSeedPage(encryptedSeed: settings.arguments as String?),
                settings: settings,
              );
            case '/intro_backup_safety':
              return MaterialPageRoute(
                builder: (_) => IntroBackupSafetyPage(),
                settings: settings,
              );
            case '/intro_backup_confirm':
              return MaterialPageRoute(
                builder: (_) => IntroBackupConfirm(),
                settings: settings,
              );
            case '/intro_import':
              return MaterialPageRoute(
                builder: (_) => IntroImportSeedPage(
                    password: (settings.arguments as Map<String, String>?)?["password"],
                    fullIdentifier: (settings.arguments as Map<String, String>?)?["fullIdentifier"]),
                settings: settings,
              );
            case '/lock_screen':
              return NoTransitionRoute(
                builder: (_) => AppLockScreen(),
                settings: settings,
              );
            case '/lock_screen_transition':
              return MaterialPageRoute(
                builder: (_) => AppLockScreen(),
                settings: settings,
              );
            case '/password_lock_screen':
              return NoTransitionRoute(
                builder: (_) => AppPasswordLockScreen(),
                settings: settings,
              );
            case '/avatar_page':
              return PageRouteBuilder(
                  pageBuilder: (BuildContext context, Animation<double> animationIn, Animation<double> animationOut) =>
                      AvatarPage(),
                  settings: settings,
                  opaque: false);
            case '/avatar_change_page':
              return MaterialPageRoute(
                builder: (_) => AvatarChangePage(curAddress: StateContainer.of(context).selectedAccount!.address),
                settings: settings,
              );
            case '/before_scan_screen':
              return NoTransitionRoute(
                builder: (_) => BeforeScanScreen(),
                settings: settings,
              );
            // nautilus API routes:
            case '/register_nano_to_username':
              return NoTransitionRoute(
                builder: (_) => RegisterNanoToUsernameScreen(),
                settings: settings,
              );
            case '/register_onchain_username':
              return NoTransitionRoute(
                builder: (_) => RegisterOnchainUsernameScreen(),
                settings: settings,
              );
            // case '/payments_page':
            //   return NoPopTransitionRoute(
            //     builder: (_) => PaymentsPage(),
            //     settings: settings,
            //   );
            case '/purchase_nano':
              return NoTransitionRoute(
                builder: (_) => PurchaseNanoScreen(),
                settings: settings,
              );
            case '/gift_paper_wallet':
              return NoTransitionRoute(
                builder: (_) => GeneratePaperWalletScreen(localCurrency: StateContainer.of(context).curCurrency),
                settings: settings,
              );
            case '/swap_xmr':
              return NoTransitionRoute(
                builder: (_) => SwapXMRScreen(localCurrency: StateContainer.of(context).curCurrency),
                settings: settings,
              );
            case '/scan':
              return NoTransitionRoute(
                builder: (_) => const ScanScreen(),
                settings: settings,
              );
            // case '/payments_page':
            //   return NoTransitionRoute(
            //     builder: (_) => PaymentsPage(),
            //     settings: settings,
            //   );
            default:
              return null;
          }
        },
      ),
    );
  }
}

/// Splash
/// Default page route that determines if user is logged in and routes them appropriately.
class Splash extends StatefulWidget {
  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<Splash> with WidgetsBindingObserver {
  late bool _hasCheckedLoggedIn;
  late bool _retried;

  bool seedIsEncrypted(String seed) {
    try {
      final String salted = NanoHelpers.bytesToUtf8String(NanoHelpers.hexToBytes(seed.substring(0, 16)));
      if (salted == "Salted__") {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> checkLoggedIn() async {
    // Update session key
    await sl.get<Vault>().updateSessionKey();
    // Check if device is rooted or jailbroken, show user a warning informing them of the risks if so
    if (Platform.isIOS || Platform.isAndroid) {
      if (!(await sl.get<SharedPrefsUtil>().getHasSeenRootWarning()) && await FlutterJailbreakDetection.jailbroken) {
        if (!mounted) return;
        AppDialogs.showConfirmDialog(
            barrierDismissible: false,
            context,
            CaseChange.toUpperCase(Z.of(context).warning, context),
            Z.of(context).rootWarning,
            Z.of(context).iUnderstandTheRisks.toUpperCase(),
            () async {
              await sl.get<SharedPrefsUtil>().setHasSeenRootWarning();
              checkLoggedIn();
            },
            cancelText: Z.of(context).exit.toUpperCase(),
            cancelAction: () {
              if (Platform.isIOS) {
                exit(0);
              } else {
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              }
            });
        return;
      }
    }
    if (!_hasCheckedLoggedIn) {
      _hasCheckedLoggedIn = true;
    } else {
      return;
    }
    try {
      // iOS key store is persistent, so if this is first launch then we will clear the keystore
      final bool firstLaunch = await sl.get<SharedPrefsUtil>().getFirstLaunch();
      if (firstLaunch) {
        await sl.get<Vault>().deleteAll();
      }
      await sl.get<SharedPrefsUtil>().setFirstLaunch();
      // See if logged in already
      bool isLoggedIn = false;
      bool isEncrypted = false;
      final String? seed = await sl.get<Vault>().getSeed();
      final String? pin = await sl.get<Vault>().getPin();
      // // If we have a seed set, but not a pin - or vice versa
      // // Then delete the seed and pin from device and start over.
      // // This would mean user did not complete the intro screen completely.
      // if (seed != null && pin != null) {
      //   isLoggedIn = true;
      //   isEncrypted = seedIsEncrypted(seed);
      // } else if (seed != null && pin == null) {
      //   await sl.get<Vault>().deleteSeed();
      // } else if (pin != null && seed == null) {
      //   await sl.get<Vault>().deletePin();
      // }

      // If we have a seed set, we are logged in
      if (seed != null) {
        isLoggedIn = true;
        isEncrypted = seedIsEncrypted(seed);
      } else if (pin != null) {
        // if the seed is null and we have a pin we should delete it:
        await sl.get<Vault>().deletePin();
      }

      if (isLoggedIn) {
        if (isEncrypted) {
          Navigator.of(context).pushReplacementNamed('/password_lock_screen');
        } else if (await sl.get<SharedPrefsUtil>().getLock() || await sl.get<SharedPrefsUtil>().shouldLock()) {
          Navigator.of(context).pushReplacementNamed('/lock_screen');
        } else {
          await NanoUtil().loginAccount(seed, context);
          final PriceConversion conversion = await sl.get<SharedPrefsUtil>().getPriceConversion();
          Navigator.of(context).pushReplacementNamed('/home', arguments: conversion);
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/intro_welcome');
      }
    } catch (e) {
      /// Fallback secure storage
      /// A very small percentage of users are encountering issues writing to the
      /// Android keyStore using the flutter_secure_storage plugin.
      ///
      /// Instead of telling them they are out of luck, this is an automatic "fallback"
      /// It will generate a 64-byte secret using the native android "bottlerocketstudios" Vault
      /// This secret is used to encrypt sensitive data and save it in SharedPreferences
      if (Platform.isAndroid && e.toString().contains("flutter_secure")) {
        if (!(await sl.get<SharedPrefsUtil>().useLegacyStorage())) {
          await sl.get<SharedPrefsUtil>().setUseLegacyStorage();
          checkLoggedIn();
        }
      } else {
        await sl.get<Vault>().deleteAll();
        await sl.get<SharedPrefsUtil>().deleteAll();
        if (!_retried) {
          _retried = true;
          _hasCheckedLoggedIn = false;
          checkLoggedIn();
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasCheckedLoggedIn = false;
    _retried = false;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => checkLoggedIn());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Account for user changing locale when leaving the app
    switch (state) {
      case AppLifecycleState.paused:
        super.didChangeAppLifecycleState(state);
        break;
      case AppLifecycleState.resumed:
        setLanguage();
        super.didChangeAppLifecycleState(state);
        break;
      default:
        super.didChangeAppLifecycleState(state);
        break;
    }
  }

  void setLanguage() {
    setState(() {
      StateContainer.of(context).deviceLocale = Localizations.localeOf(context);
    });
    sl.get<SharedPrefsUtil>().getLanguage().then((LanguageSetting setting) {
      setState(() {
        StateContainer.of(context).updateLanguage(setting);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // This seems to be the earliest place we can retrieve the device Locale
    setLanguage();
    sl.get<SharedPrefsUtil>().getCurrency(StateContainer.of(context).deviceLocale).then((AvailableCurrency currency) {
      StateContainer.of(context).curCurrency = currency;
    });
    return Scaffold(
      backgroundColor: StateContainer.of(context).curTheme.background,
    );
  }
}
