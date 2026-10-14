<?php

declare(strict_types=1);

namespace PhpWing\Model;

/** Response of the authorization API. */
final readonly class AuthorizationResponse
{
    /**
     * @param ?string $token authorization token (a JWT), on success
     * @param ?string $confirmUrl Wing's payment page for the token: redirect the payer there
     */
    public function __construct(
        public Status $status,
        public ?string $token = null,
        public ?string $confirmUrl = null,
    ) {}

    /** Whether Wing authorized the payment. */
    public function isSuccess(): bool
    {
        return $this->status->isSuccess() && $this->token !== null && $this->token !== '';
    }
}
