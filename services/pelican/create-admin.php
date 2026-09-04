<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$email = getenv('ADMIN_EMAIL') ?: 'admin@example.com';
$username = getenv('ADMIN_USERNAME') ?: 'admin';
$password = getenv('ADMIN_PASSWORD') ?: 'password';

$service = app(\App\Services\Users\UserCreationService::class);

// Look up by email OR username (root_admin column no longer exists in modern Pelican)
$user = \App\Models\User::where('email', $email)->orWhere('username', $username)->first();

if ($user) {
    echo "Admin already exists ({$user->username}), updating password...\n";
    $user->password = $password;
    $user->save();
    // Ensure root admin role
    $user->syncRoles(\App\Models\Role::getRootAdmin());
    echo "Root Admin role ensured, password updated\n";
} else {
    $user = $service->handle([
        'email' => $email,
        'username' => $username,
        'password' => $password,
        'root_admin' => true,
    ]);
    echo "Admin user created via UserCreationService\n";
}

echo "Credentials: $username / $password\n";