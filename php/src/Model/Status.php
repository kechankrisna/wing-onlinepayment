<?php

declare(strict_types=1);

namespace PhpWing\Model;

/** `errorCode` and `errorText` of Wing responses. Success is `200`. */
final readonly class Status
{
    public function __construct(
        public string $code,
        public string $message,
    ) {}

    /** Whether Wing answered `200`. */
    public function isSuccess(): bool
    {
        return $this->code === '200';
    }

    /** @param array<array-key, mixed> $json */
    public static function fromArray(array $json): self
    {
        return new self(Json::string($json, 'errorCode'), Json::string($json, 'errorText'));
    }
}
