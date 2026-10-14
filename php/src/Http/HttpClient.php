<?php

declare(strict_types=1);

namespace PhpWing\Http;

use PhpWing\Exception\WingException;

/**
 * Sends one POST request. Implement it to plug in any HTTP stack, or use
 * {@see CurlHttpClient} (default) or {@see Psr18HttpClient}.
 */
interface HttpClient
{
    /**
     * POST `$body` to `$url` and return the reply, whatever its status code.
     *
     * @param array<string, string> $headers
     *
     * @throws WingException when no reply was received
     */
    public function post(string $url, array $headers, string $body): HttpResponse;
}
