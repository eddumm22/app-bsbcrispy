import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';
import 'services/stock_count_service.dart';
import 'services/receipt_service.dart';
import 'services/unit_service.dart';
import 'services/user_profile_service.dart';
import 'services/supplier_service.dart';
import 'services/dashboard_service.dart';
import 'services/rating_service.dart';
import 'state/auth_controller.dart';
import 'ui/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TaskflowApp());
}

class TaskflowApp extends StatelessWidget {
  const TaskflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<ProductService>(
          create: (_) => ProductService(),
        ),
        Provider<StockCountService>(
          create: (_) => StockCountService(),
        ),
        Provider<ReceiptService>(
          create: (_) => ReceiptService(),
        ),
        Provider<UnitService>(
          create: (_) => UnitService(),
        ),
        Provider<SupplierService>(
          create: (_) => SupplierService(),
        ),
        Provider<DashboardService>(
          create: (_) => DashboardService(),
        ),
        Provider<RatingService>(
          create: (_) => RatingService(),
        ),
        Provider<UserProfileService>(
          create: (_) => UserProfileService(),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            context.read<AuthService>(),
            context.read<UserProfileService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'BSB Crispy',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: const AuthGate(),
      ),
    );
  }
}

