// Maps an authorized payment event to its settlement counterpart.
function toPaymentSettlement(PaymentAuthorized paymentAuthorized) returns PaymentSettlement => {
    paymentId: paymentAuthorized.paymentId,
    orderId: paymentAuthorized.orderId,
    merchantId: paymentAuthorized.merchantId,
    amount: paymentAuthorized.amount,
    currency: paymentAuthorized.currency
};
