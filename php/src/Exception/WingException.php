<?php

declare(strict_types=1);

namespace PhpWing\Exception;

/**
 * Thrown when Wing could not be reached or did not answer with an
 * `errorCode`, and for invalid local input such as a short password. Branch
 * on {@see $type}.
 *
 * Wing business errors (invalid REST API key, transaction not found, ...)
 * are not thrown: they are returned in the response `status`.
 */
final class WingException extends \RuntimeException
{
    /**
     * @param ErrorType $type what went wrong
     * @param ?int $statusCode HTTP status code, when a response was received
     */
    public function __construct(
        public readonly ErrorType $type,
        string $message,
        public readonly ?int $statusCode = null,
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }

    /** Whether retrying the same call later may succeed. */
    public function isRetryable(): bool
    {
        return match ($this->type) {
            ErrorType::Connection, ErrorType::Timeout => true,
            ErrorType::UnexpectedResponse => ($this->statusCode ?? 0) >= 500,
            default => false,
        };
    }
}
