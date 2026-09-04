<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$email = getenv('ADMIN_EMAIL') ?: 'admin@example.com';
$username = getenv('ADMIN_USERNAME') ?: 'admin';
$password = getenv('ADMIN_PASSWORD') ?: 'password';

// Check if admin already exists
$user = \App\Models\User::where('root_admin', 1)->first();
if ($user) {
    echo "Admin already exists, updating password...\n";
    $user->password = password_hash($password, PASSWORD_BCRYPT);
    $user->save();
    echo "Admin password updated\n";
} else {
    // Use UserCreationService to create admin with root_admin role
    $service = app(\App\Services\Users\UserCreationService::class);
    $user = $service->handle([
        'email' => $email,
        'username' => $username,
        'password' => $password,
        'root_admin' => true,
    ]);
    echo "Admin user created\n";
}

echo "Credentials: $username / $password\n";
