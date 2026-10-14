<?php

declare(strict_types=1);

namespace PhpWing\Model;

/** Response of the transaction inquiry API. */
final readonly class InquiryResponse
{
    public function __construct(
        public Status $status,
        public ?Transaction $transaction = null,
    ) {}

    /** Whether Wing found the transaction. */
    public function isSuccess(): bool
    {
        return $this->status->isSuccess() && $this->transaction !== null;
    }

    /** Whether the transaction was found and its amount is at least `$price`. */
    public function isPaid(int|float $price): bool
    {
        return $this->isSuccess() && $this->transaction?->covers($price) === true;
    }

    /**
     * The transaction fields are at the top level, or inside `data`.
     *
     * @param array<array-key, mixed> $json
     */
    public static function fromArray(array $json): self
    {
        $status = Status::fromArray($json);
        if (!$status->isSuccess()) {
            return new self($status);
        }
        $data = $json['data'] ?? null;

        return new self($status, Transaction::fromArray(\is_array($data) ? $data : $json));
    }
}
