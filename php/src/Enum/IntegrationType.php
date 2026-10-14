<?php

declare(strict_types=1);

namespace PhpWing\Enum;

/** Where Wing sends the payer after paying (`integration_type`). */
enum IntegrationType: string
{
    /** back to `return_url` in the browser (Wing's default) */
    case WebApp = 'WEBAPP';

    /** back into your app through the deep link you registered with Wing */
    case MobileApp = 'MOBAPP';
}
