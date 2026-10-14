<?php

declare(strict_types=1);

namespace PhpWing\Http;

use PhpWing\Exception\ErrorType;
use PhpWing\Exception\WingException;
use Psr\Http\Client\ClientExceptionInterface;
use Psr\Http\Client\ClientInterface;
use Psr\Http\Client\NetworkExceptionInterface;
use Psr\Http\Message\RequestFactoryInterface;
use Psr\Http\Message\StreamFactoryInterface;

/**
 * {@see HttpClient} on top of any PSR-18 client (Guzzle, Symfony HttpClient,
 * ...). Timeouts and TLS are configured on that client.
 *
 * ```php
 * $factory = new \GuzzleHttp\Psr7\HttpFactory();
 * $http = new Psr18HttpClient(new \GuzzleHttp\Client(['timeout' => 30]), $factory, $factory);
 * ```
 */
final class Psr18HttpClient implements HttpClient
{
    public function __construct(
        private readonly ClientInterface $client,
        private readonly RequestFactoryInterface $requestFactory,
        private readonly StreamFactoryInterface $streamFactory,
    ) {}

    public function post(string $url, array $headers, string $body): HttpResponse
    {
        $request = $this->requestFactory
            ->createRequest('POST', $url)
            ->withBody($this->streamFactory->createStream($body));
        foreach ($headers as $name => $value) {
            $request = $request->withHeader($name, $value);
        }

        try {
            $response = $this->client->sendRequest($request);
        } catch (NetworkExceptionInterface $e) {
            throw new WingException(ErrorType::Connection, 'Could not connect to Wing', null, $e);
        } catch (ClientExceptionInterface $e) {
            throw new WingException(ErrorType::Unknown, 'Request to Wing failed: ' . $e->getMessage(), null, $e);
        }

        return new HttpResponse($response->getStatusCode(), (string) $response->getBody());
    }
}
