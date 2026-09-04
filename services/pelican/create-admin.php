<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$user = \App\Models\User::where('admin', true)->first();
if ($user) {
    echo "Admin already exists, updating password...\n";
}

$email = getenv('ADMIN_EMAIL') ?: 'admin@example.com';
$username = getenv('ADMIN_USERNAME') ?: 'admin';
$password = getenv('ADMIN_PASSWORD') ?: 'password';

if ($user) {
    $user->password = password_hash($password, PASSWORD_BCRYPT);
    $user->save();
} else {
    $user = \App\Models\User::create([
        'name' => $username,
        'email' => $email,
        'password' => password_hash($password, PASSWORD_BCRYPT),
        'admin' => true,
    ]);
}
echo "Admin user ready: $username / $password\n";
