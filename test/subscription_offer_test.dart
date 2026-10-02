import 'package:esign_doc_pro/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  const weeklyPhase = PricingPhaseWrapper(
    billingCycleCount: 0,
    billingPeriod: 'P1W',
    formattedPrice: 'Rs 1,950',
    priceAmountMicros: 1950000000,
    priceCurrencyCode: 'PKR',
    recurrenceMode: RecurrenceMode.infiniteRecurring,
  );
  const trialPhase = PricingPhaseWrapper(
    billingCycleCount: 1,
    billingPeriod: 'P3D',
    formattedPrice: 'Rs 0',
    priceAmountMicros: 0,
    priceCurrencyCode: 'PKR',
    recurrenceMode: RecurrenceMode.finiteRecurring,
  );

  List<GooglePlayProductDetails> products({required bool includeTrial}) {
    return GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        description: 'Weekly plan',
        name: 'eSign Pro',
        productId: SubscriptionService.weeklyProductId,
        productType: ProductType.subs,
        title: 'eSign Pro',
        subscriptionOfferDetails: [
          const SubscriptionOfferDetailsWrapper(
            basePlanId: 'weekly',
            offerTags: [],
            offerIdToken: 'base-token',
            pricingPhases: [weeklyPhase],
          ),
          if (includeTrial)
            const SubscriptionOfferDetailsWrapper(
              basePlanId: 'weekly',
              offerId: 'three-day-trial',
              offerTags: [],
              offerIdToken: 'trial-token',
              pricingPhases: [trialPhase, weeklyPhase],
            ),
        ],
      ),
    );
  }

  test('selects eligible three-day offer and shows renewal price', () {
    final offer =
        SubscriptionService.selectWeeklyOffer(products(includeTrial: true));
    expect(offer, isNotNull);
    expect(offer!.hasThreeDayTrial, isTrue);
    expect(offer.renewalPrice, 'Rs 1,950');
    expect(
        (offer.product as GooglePlayProductDetails).offerToken, 'trial-token');
  });

  test('falls back to weekly base plan when no trial is returned', () {
    final offer =
        SubscriptionService.selectWeeklyOffer(products(includeTrial: false));
    expect(offer, isNotNull);
    expect(offer!.hasThreeDayTrial, isFalse);
    expect(offer.renewalPrice, 'Rs 1,950');
    expect(
        (offer.product as GooglePlayProductDetails).offerToken, 'base-token');
  });
}
