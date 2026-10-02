import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

enum SubscriptionPlan { weekly, monthly, yearly }

class SubscriptionOffer {
  final SubscriptionPlan plan;
  final ProductDetails product;
  final String renewalPrice;
  final bool hasThreeDayTrial;

  const SubscriptionOffer({
    required this.plan,
    required this.product,
    required this.renewalPrice,
    required this.hasThreeDayTrial,
  });

  String get periodLabel => switch (plan) {
        SubscriptionPlan.weekly => 'Weekly',
        SubscriptionPlan.monthly => 'Monthly',
        SubscriptionPlan.yearly => 'Yearly',
      };

  String get periodSuffix => switch (plan) {
        SubscriptionPlan.weekly => '/week',
        SubscriptionPlan.monthly => '/month',
        SubscriptionPlan.yearly => '/year',
      };
}

typedef WeeklySubscriptionOffer = SubscriptionOffer;

class SubscriptionService {
  static const weeklyProductId = 'esign_doc_pro_weekly';
  static const monthlyProductId = 'esign_doc_pro_monthly';
  static const yearlyProductId = 'esign_doc_pro_yearly';
  static const trialLengthDays = 3;
  static const _subscriptionStatusChannel =
      MethodChannel('esign_doc_pro/subscription_status');

  static const productIds = <String>{
    weeklyProductId,
    monthlyProductId,
    yearlyProductId,
  };

  final InAppPurchase _billing = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool isPremium = false;

  Future<bool> hasActiveEntitlement() async {
    if (!Platform.isIOS) return false;
    try {
      return await _subscriptionStatusChannel
              .invokeMethod<bool>('hasActiveEntitlement') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> initialize(
      {required void Function(bool active) onEntitlementChanged}) async {
    if (!await _billing.isAvailable()) return;
    _purchaseSubscription = _billing.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (productIds.contains(purchase.productID) &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored)) {
          isPremium = true;
          onEntitlementChanged(true);
        }
        if (purchase.pendingCompletePurchase) {
          _billing.completePurchase(purchase);
        }
      }
    });
  }

  Future<bool> purchasePlan(SubscriptionOffer offer) async {
    if (!await _billing.isAvailable()) return false;
    return _billing.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: offer.product),
    );
  }

  Future<bool> purchaseWeekly({WeeklySubscriptionOffer? selectedOffer}) async {
    final offer = selectedOffer ?? await loadOffer(SubscriptionPlan.weekly);
    return offer == null ? false : await purchasePlan(offer);
  }

  Future<List<SubscriptionOffer>> loadOffers() async {
    if (!await _billing.isAvailable()) return const [];
    final response = await _billing.queryProductDetails(productIds);
    final offers = <SubscriptionOffer>[];
    for (final plan in SubscriptionPlan.values) {
      final offer = await _selectOfferForPlan(plan, response.productDetails);
      if (offer != null) offers.add(offer);
    }
    return offers;
  }

  Future<SubscriptionOffer?> loadOffer(SubscriptionPlan plan) async {
    if (!await _billing.isAvailable()) return null;
    final response = await _billing.queryProductDetails({productIdFor(plan)});
    return _selectOfferForPlan(plan, response.productDetails);
  }

  static String productIdFor(SubscriptionPlan plan) => switch (plan) {
        SubscriptionPlan.weekly => weeklyProductId,
        SubscriptionPlan.monthly => monthlyProductId,
        SubscriptionPlan.yearly => yearlyProductId,
      };

  Future<SubscriptionOffer?> _selectOfferForPlan(
      SubscriptionPlan plan, Iterable<ProductDetails> products) async {
    final productId = productIdFor(plan);
    if (Platform.isIOS) {
      ProductDetails? product;
      for (final candidate in products) {
        if (candidate.id == productId) {
          product = candidate;
          break;
        }
      }
      if (product == null) return null;
      var eligibleForTrial = false;
      try {
        final storeKit = InAppPurchasePlatform.instance;
        if (storeKit is InAppPurchaseStoreKitPlatform) {
          eligibleForTrial =
              await storeKit.isIntroductoryOfferEligible(product.id);
        }
      } catch (_) {
        // The App Store purchase sheet remains authoritative on older devices.
      }
      return SubscriptionOffer(
        plan: plan,
        product: product,
        renewalPrice: product.price,
        hasThreeDayTrial: eligibleForTrial,
      );
    }
    return selectOffer(products, productId, plan);
  }

  static SubscriptionOffer? selectOffer(Iterable<ProductDetails> products,
      String productId, SubscriptionPlan plan) {
    SubscriptionOffer? standardOffer;
    for (final product in products) {
      if (product.id != productId) continue;
      if (product is GooglePlayProductDetails &&
          product.subscriptionIndex != null) {
        final details = product.productDetails
            .subscriptionOfferDetails![product.subscriptionIndex!];
        if (details.pricingPhases.isEmpty) continue;
        final firstPhase = details.pricingPhases.first;
        final renewalPhase = details.pricingPhases.last;
        final expectedPeriod = switch (plan) {
          SubscriptionPlan.weekly => 'P1W',
          SubscriptionPlan.monthly => 'P1M',
          SubscriptionPlan.yearly => 'P1Y',
        };
        if (renewalPhase.billingPeriod.toUpperCase() != expectedPeriod ||
            renewalPhase.priceAmountMicros <= 0) {
          continue;
        }
        final isThreeDayTrial = firstPhase.priceAmountMicros == 0 &&
            firstPhase.billingPeriod.toUpperCase() == 'P3D';
        final offer = SubscriptionOffer(
          plan: plan,
          product: product,
          renewalPrice: renewalPhase.formattedPrice,
          hasThreeDayTrial: isThreeDayTrial,
        );
        if (isThreeDayTrial) return offer;
        if (details.offerId == null) standardOffer = offer;
      } else {
        standardOffer ??= SubscriptionOffer(
          plan: plan,
          product: product,
          renewalPrice: product.price,
          hasThreeDayTrial: false,
        );
      }
    }
    return standardOffer;
  }

  static WeeklySubscriptionOffer? selectWeeklyOffer(
      Iterable<ProductDetails> products) {
    return selectOffer(products, weeklyProductId, SubscriptionPlan.weekly);
  }

  Future<void> restorePurchases() async {
    if (await _billing.isAvailable()) {
      await _billing.restorePurchases();
    }
  }

  Future<void> dispose() async => _purchaseSubscription?.cancel();
}
