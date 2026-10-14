<?php

declare(strict_types=1);

namespace PhpWing\Exception;

/** What went wrong in a {@see WingException}. */
enum ErrorType: string
{
    /** Wing could not be reached (DNS, refused connection, offline, ...) */
    case Connection = 'connection';

    /** the request took longer than the configured timeout */
    case Timeout = 'timeout';

    /** the call was cancelled */
    case Cancelled = 'cancelled';

    /** Wing's TLS certificate was rejected */
    case BadCertificate = 'badCertificate';

    /** Wing answered without an `errorCode` (e.g. an HTML page) */
    case UnexpectedResponse = 'unexpectedResponse';

    /** the payload could not be encrypted (e.g. a password shorter than 16 bytes) */
    case Encryption = 'encryption';

    /** callback contents do not decrypt with the password, or are not a JSON object */
    case InvalidCallback = 'invalidCallback';

    /** any other failure; see the previous exception */
    case Unknown = 'unknown';
}
