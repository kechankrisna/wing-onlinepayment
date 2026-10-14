<?php

declare(strict_types=1);

namespace PhpWing\Model;

/**
 * A Wing payment, as returned by the inquiry API and pushed to your callback
 * URL. Wing asks partners to accept only payments whose `amount` is at least
 * the price: check {@see covers()} before delivering.
 */
final readonly class Transaction
{
    /**
     * @param float $amount amount the partner requested
     * @param string $orderReferenceNo your `order_reference_no`
     * @param string $transactionId Wing transaction id; show it on your success page
     * @param ?float $totalAmount total amount, which can include a fee or an exchange rate
     * @param array<array-key, mixed> $raw every field Wing sent
     */
    public function __construct(
        public float $amount,
        public string $orderReferenceNo,
        public string $transactionId,
        public ?float $totalAmount = null,
        public ?string $currency = null,
        public ?string $remark = null,
        public ?string $customerName = null,
        public ?float $fee = null,
        public ?string $feeCurrency = null,
        public ?string $wingAccount = null,
        public ?string $psTrnId = null,
        public ?string $fcTrnId = null,
        public ?string $billerName = null,
        public ?string $transactionDate = null,
        public array $raw = [],
    ) {}

    /** Whether `amount` is at least `$price`, compared in cents. */
    public function covers(int|float $price): bool
    {
        return round($this->amount * 100) >= round($price * 100);
    }

    /** @param array<array-key, mixed> $json */
    public static function fromArray(array $json): self
    {
        return new self(
            amount: Json::float($json, 'amount'),
            orderReferenceNo: Json::string($json, 'order_reference_no'),
            transactionId: Json::string($json, 'transaction_id'),
            totalAmount: Json::optionalFloat($json, 'total_amount'),
            currency: Json::optionalString($json, 'currency'),
            remark: Json::optionalString($json, 'remark'),
            customerName: Json::optionalString($json, 'customer_name'),
            fee: Json::optionalFloat($json, 'fee'),
            feeCurrency: Json::optionalString($json, 'fee_currency'),
            wingAccount: Json::optionalString($json, 'wing_account'),
            psTrnId: Json::optionalString($json, 'ps_trn_id'),
            fcTrnId: Json::optionalString($json, 'fc_trn_id'),
            billerName: Json::optionalString($json, 'biller_name'),
            transactionDate: Json::optionalString($json, 'transaction_date'),
            raw: $json,
        );
    }
}
